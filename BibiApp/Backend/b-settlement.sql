-- B settlement: client-reported local purchases and independently owned web orders.
-- This does not verify Apple receipts or change the existing Apple verifier.
insert into bibi_private.products(id,diamonds) values
 ('fyongbrslseicxya',16800),('xutwylpejsdvkwpm',42700) on conflict(id) do nothing;
do $$ begin
 if (select count(*) from bibi_private.products where (id,diamonds) in
  (('ldbsrbbhebevxdjf',400),('fxvrdbmlwopeasti',800),('akafhhbydyymfpzk',2450),
   ('ffzwgpuvsyyhaeeg',5150),('ofgjvlbwtzchgvbx',10800),('fyongbrslseicxya',16800),
   ('azacbzpzvvvpblzu',29400),('xutwylpejsdvkwpm',42700),('lghwqjsuuxivrdrf',63700)))<>9
 then raise exception 'Wallet catalog differs from the approved nine products.'; end if;
end $$;

-- Historical A rows were created by the existing Apple-server verification path.
-- New B client-trusted rows explicitly carry different provenance.
alter table bibi_private.apple_transactions add column if not exists verification_source text not null default 'apple_server';
alter table bibi_private.apple_transactions add constraint bibi_transaction_verification_source_check
 check(verification_source in ('apple_server','client_reported'));

create table bibi_private.settlements (
 bundle_id text not null check(bundle_id='com.bibi.quadratic'),
 environment text not null check(environment in ('Sandbox','Production')),
 transaction_id text not null check(char_length(transaction_id) between 1 and 100),
 user_id uuid not null,
 source text not null check(source in ('bibi_wallet','constellation_order')),
 product_id text not null check(char_length(product_id) between 1 and 255),
 quantity integer not null check(quantity between 1 and 10),
 order_reference text,
 contract_id text not null check(contract_id='bibi-48369038-v1'),
 client_context jsonb not null default '{}' check(jsonb_typeof(client_context)='object'),
 state text not null check(state in ('prepared','processing','upstreamConfirmed','confirmed','rejected','needsReconciliation')),
 authority text not null check(authority in ('supabase','external')),
 provenance text not null check(provenance in ('client_reported','upstream_http_confirmation','legacy_apple_server')),
 receipt_sha256 text check(receipt_sha256 is null or receipt_sha256 ~ '^[a-f0-9]{64}$'),
 evidence_version integer not null default 1,
 attempt_receipt_sha256 text,
 lease_owner uuid, lease_generation integer not null default 0, lease_until timestamptz,
 forwarding_started boolean not null default false,
 upstream_confirmed_at timestamptz,
 amount bigint, result jsonb, error_category text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 primary key(bundle_id,environment,transaction_id),
 check(source<>'bibi_wallet' or (authority='supabase' and order_reference is null)),
 check(source<>'constellation_order' or authority='external')
);
-- Retain financial ownership evidence across account deletion, as the A ledger
-- does. No current/new account can claim another UUID's historical transaction.
create index bibi_settlements_user_idx on bibi_private.settlements(user_id);
alter table bibi_private.settlements enable row level security;
revoke all on bibi_private.settlements from public,anon,authenticated;
grant all on bibi_private.settlements to service_role;
create policy bibi_no_client_access on bibi_private.settlements for all to authenticated using(false) with check(false);

create function bibi_private.settlement_error(p_code integer,p_category text,p_state text) returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_object('code',p_code,'category',p_category,'state',p_state,'message',case p_category
  when 'association_missing' then 'The original purchase association needs reconciliation.'
  when 'ownership_conflict' then 'This transaction belongs to a different purchase context.'
  when 'invalid_input' then 'The purchase details are invalid.'
  when 'configuration' then 'Purchase configuration is unavailable.'
  when 'processing' then 'This purchase is still being confirmed.'
  when 'needs_reconciliation' then 'The original confirmation outcome needs reconciliation.'
  when 'upstream_rejected' then 'The original service did not confirm this purchase.'
  when 'session_expired' then 'Restore the original account to continue.'
  else 'The purchase confirmation could not be completed. Retry its status later.' end)
$$;
revoke all on function bibi_private.settlement_error(integer,text,text) from public,anon,authenticated;

create function bibi_private.settlement_view(p_row bibi_private.settlements) returns jsonb
language sql stable set search_path='' as $$
 select (case when p_row.state='confirmed' then p_row.result
  else bibi_private.settlement_error(case when p_row.state='processing' then 202 else 409 end,
   coalesce(p_row.error_category,case when p_row.state='processing' then 'processing' else 'needs_reconciliation' end),p_row.state)
  end) || jsonb_build_object('transaction_id',p_row.transaction_id,'environment',p_row.environment,
   'source',p_row.source,'product_id',p_row.product_id,'quantity',p_row.quantity,'authority',p_row.authority,
   'recovery',p_row.client_context || jsonb_strip_nulls(jsonb_build_object('contract_id',p_row.contract_id,
    'order_reference',p_row.order_reference,'provenance',p_row.provenance)))
$$;
revoke all on function bibi_private.settlement_view(bibi_private.settlements) from public,anon,authenticated;

-- Only the authenticated Edge adapter may call this service-role API. Clients
-- cannot choose p_user, credit amounts, arbitrary upstream targets or lease IDs.
create function bibi_private.settlement(p_user uuid,p_action text,p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare
 app constant text := 'com.bibi.quadratic'; contract constant text := 'bibi-48369038-v1';
 env text := p_request->>'environment'; tx text := p_request->>'transaction_id';
 origin text := p_request->>'source'; product text := p_request->>'product_id';
 qty integer := (p_request->>'quantity')::integer; order_ref text := p_request->>'order_reference';
 context jsonb := coalesce(p_request->'context','{}'::jsonb); evidence text := p_request->>'receipt_sha256';
 item bibi_private.settlements; legacy bibi_private.apple_transactions;
 prior_legacy boolean; current_balance bigint; receipt jsonb; price bigint; owner uuid;
begin
 if p_user is null or not exists(select 1 from public.bibi_profiles p join public.bibi_consents c on c.user_id=p.id
  where p.id=p_user and p.account_status='active' and c.adult_declared) then
  return bibi_private.settlement_error(401,'session_expired','needsReconciliation');
 end if;
 if env is null or env not in ('Sandbox','Production') then
  return bibi_private.settlement_error(400,'invalid_input','needsReconciliation');
 end if;
 if p_action='availability' then
  if origin is null or origin not in ('bibi_wallet','constellation_order') or qty is distinct from 1 or product is null then
   return bibi_private.settlement_error(400,'invalid_input','needsReconciliation'); end if;
  return jsonb_build_object('code',0,'message','ok','available',case when origin='bibi_wallet' then
   exists(select 1 from bibi_private.products where id=product) else true end,
   'source',origin,'environment',env,'authority',case when origin='bibi_wallet' then 'supabase' else 'external' end,
   'client_trusted_local',true);
 end if;
 if tx is null or tx !~ '^[0-9]{1,100}$' then return bibi_private.settlement_error(400,'invalid_input','needsReconciliation'); end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 perform pg_advisory_xact_lock(hashtextextended(env||':'||tx,2));
 select * into item from bibi_private.settlements where bundle_id=app and environment=env and transaction_id=tx for update;
 select * into legacy from bibi_private.apple_transactions where environment=env and transaction_id=tx;
 prior_legacy := found;

 if p_action='status' then
  if item.user_id is not null and item.user_id<>p_user then return bibi_private.settlement_error(404,'association_missing','needsReconciliation'); end if;
  if item.user_id is null then
   if not prior_legacy or legacy.user_id<>p_user or legacy.verification_source<>'apple_server' or legacy.revoked then
    return bibi_private.settlement_error(404,'association_missing','needsReconciliation'); end if;
   select balance into current_balance from public.bibi_wallets where user_id=p_user and environment=env;
   insert into bibi_private.settlements(bundle_id,environment,transaction_id,user_id,source,product_id,quantity,
    contract_id,state,authority,provenance,amount,result)
   values(app,env,tx,p_user,'bibi_wallet',legacy.product_id,legacy.quantity,contract,'confirmed','supabase','legacy_apple_server',legacy.amount,
    jsonb_build_object('code',0,'message','ok','state','confirmed','balance',current_balance)) returning * into item;
  end if;
  if item.source='bibi_wallet' and exists(select 1 from bibi_private.apple_revocations where environment=env and transaction_id=tx) then
   return bibi_private.settlement_error(409,'ownership_conflict','needsReconciliation'); end if;
  if item.state='upstreamConfirmed' then
   update bibi_private.settlements set state='confirmed',result=jsonb_build_object('code',0,'message','ok','state','confirmed'),updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx returning * into item;
  elsif item.state='processing' and item.lease_until<clock_timestamp() and item.forwarding_started then
   update bibi_private.settlements set state='needsReconciliation',error_category='needs_reconciliation',updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx returning * into item;
  end if;
  return bibi_private.settlement_view(item);
 end if;

 if p_action in ('mark_forwarding','record_upstream','finalize_remote','record_outcome') then
  if item.user_id is distinct from p_user or item.source<>'constellation_order' then
   return bibi_private.settlement_error(409,'ownership_conflict','needsReconciliation'); end if;
  if item.state='confirmed' then return bibi_private.settlement_view(item); end if;
  owner := nullif(p_request->>'lease_owner','')::uuid;
  if owner is null or item.lease_owner is distinct from owner then
   return bibi_private.settlement_error(409,'processing',item.state); end if;
  if p_action='mark_forwarding' then
   if item.state<>'processing' or item.forwarding_started or item.lease_until<clock_timestamp() then
    return bibi_private.settlement_view(item); end if;
   update bibi_private.settlements set forwarding_started=true,updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx;
   return jsonb_build_object('code',0,'dispatch',true);
  elsif p_action='record_upstream' then
   if item.state not in ('processing','needsReconciliation','upstreamConfirmed') or not item.forwarding_started then
    return bibi_private.settlement_error(409,'needs_reconciliation',item.state); end if;
   update bibi_private.settlements set state='upstreamConfirmed',upstream_confirmed_at=coalesce(upstream_confirmed_at,now()),error_category=null,updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx;
   return jsonb_build_object('code',0,'state','upstreamConfirmed');
  elsif p_action='finalize_remote' then
   if item.state<>'upstreamConfirmed' then return bibi_private.settlement_view(item); end if;
   update bibi_private.settlements set state='confirmed',result=jsonb_build_object('code',0,'message','ok','state','confirmed'),updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx returning * into item;
   return bibi_private.settlement_view(item);
  else
   if item.state not in ('processing','needsReconciliation') then return bibi_private.settlement_view(item); end if;
   update bibi_private.settlements set state=case when p_request->>'outcome'='rejected' then 'rejected' else 'needsReconciliation' end,
    error_category=case when p_request->>'outcome'='rejected' then 'upstream_rejected' else 'needs_reconciliation' end,updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx returning * into item;
   return bibi_private.settlement_view(item);
  end if;
 end if;

 if p_action not in ('settle_local','claim_remote') or origin is null or origin not in ('bibi_wallet','constellation_order')
  or qty is distinct from 1 or product is null or char_length(product) not between 1 and 255
  or p_request->>'contract_id' is distinct from contract or jsonb_typeof(context)<>'object'
  or evidence is null or evidence !~ '^[a-f0-9]{64}$'
  or (origin='bibi_wallet' and (p_action<>'settle_local' or order_ref is not null))
  or (origin='constellation_order' and p_action<>'claim_remote') then
  return bibi_private.settlement_error(400,'invalid_input','needsReconciliation'); end if;
 if prior_legacy and (origin<>'bibi_wallet' or legacy.user_id<>p_user or legacy.product_id<>product or legacy.quantity<>qty or legacy.revoked) then
  return bibi_private.settlement_error(409,'ownership_conflict','needsReconciliation'); end if;
 if item.user_id is not null then
  if item.user_id<>p_user or item.source<>origin or item.product_id<>product or item.quantity<>qty
   or item.order_reference is distinct from order_ref
   or (item.provenance<>'legacy_apple_server' and item.client_context<>context) then
   return bibi_private.settlement_error(409,'ownership_conflict','needsReconciliation'); end if;
  if item.state='confirmed' then return bibi_private.settlement_view(item); end if;
  if item.state='upstreamConfirmed' then
   update bibi_private.settlements set state='confirmed',result=jsonb_build_object('code',0,'message','ok','state','confirmed'),updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx returning * into item;
   return bibi_private.settlement_view(item);
  end if;
  -- Evidence can be replaced without changing frozen business ownership. This
  -- does not authorize a second unknown/rejected upstream side effect.
  if item.receipt_sha256 is distinct from evidence then
   update bibi_private.settlements set receipt_sha256=evidence,evidence_version=evidence_version+1,updated_at=now()
    where bundle_id=app and environment=env and transaction_id=tx returning * into item;
  end if;
  if item.state in ('rejected','needsReconciliation') then return bibi_private.settlement_view(item); end if;
  if item.state='processing' then
   if item.lease_until>=clock_timestamp() then return bibi_private.settlement_view(item); end if;
   if item.forwarding_started then
    update bibi_private.settlements set state='needsReconciliation',error_category='needs_reconciliation',updated_at=now()
     where bundle_id=app and environment=env and transaction_id=tx returning * into item;
    return bibi_private.settlement_view(item);
   end if;
  end if;
 else
  if origin='bibi_wallet' and not exists(select 1 from bibi_private.products where id=product) then
   return bibi_private.settlement_error(503,'configuration','needsReconciliation'); end if;
  insert into bibi_private.settlements(bundle_id,environment,transaction_id,user_id,source,product_id,quantity,order_reference,
   contract_id,client_context,state,authority,provenance,receipt_sha256)
  values(app,env,tx,p_user,origin,product,qty,order_ref,contract,context,'prepared',
   case when origin='bibi_wallet' then 'supabase' else 'external' end,
   case when origin='bibi_wallet' then 'client_reported' else 'upstream_http_confirmation' end,evidence)
  returning * into item;
 end if;
 if origin='bibi_wallet' then
  receipt := bibi_private.credit_purchase(p_user,tx,env,product,qty);
  if not prior_legacy then
   update bibi_private.apple_transactions set verification_source='client_reported' where environment=env and transaction_id=tx;
  end if;
  update bibi_private.settlements set state='confirmed',amount=(select amount from bibi_private.apple_transactions where environment=env and transaction_id=tx),
   provenance=case when prior_legacy and legacy.verification_source='apple_server' then 'legacy_apple_server' else provenance end,
   result=jsonb_build_object('code',0,'message','ok','state','confirmed','balance',receipt->'balance'),updated_at=now()
   where bundle_id=app and environment=env and transaction_id=tx returning * into item;
  return bibi_private.settlement_view(item);
 end if;
 owner := gen_random_uuid();
 update bibi_private.settlements set state='processing',lease_owner=owner,lease_generation=lease_generation+1,
  lease_until=clock_timestamp()+interval '45 seconds',forwarding_started=false,attempt_receipt_sha256=evidence,updated_at=now()
  where bundle_id=app and environment=env and transaction_id=tx;
 return jsonb_build_object('code',0,'state','processing','dispatch',true,'lease_owner',owner);
end $$;
revoke all on function bibi_private.settlement(uuid,text,jsonb) from public,anon,authenticated;

create function public.bibi_settlement(p_user uuid,p_action text,p_request jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select bibi_private.settlement(p_user,p_action,p_request) $$;
revoke all on function public.bibi_settlement(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function bibi_private.settlement(uuid,text,jsonb),public.bibi_settlement(uuid,text,jsonb) to service_role;

-- The retired App adapter must not bypass B's cross-source transaction binding.
-- Keep its genuine Apple verification and existing refund mechanics unchanged.
do $patch$
declare source text := pg_get_functiondef('bibi_private.credit_purchase(uuid,text,text,text,integer)'::regprocedure);
 needle text := 'perform pg_advisory_xact_lock(hashtextextended(p_environment||'':''||p_transaction,2));';
begin
 if position(needle in source)=0 then raise exception 'Expected purchase lock was not found.'; end if;
 source := replace(source,needle,needle || E'\n if exists(select 1 from bibi_private.settlements s where s.bundle_id=''com.bibi.quadratic'' and s.environment=p_environment and s.transaction_id=p_transaction and (s.user_id<>p_user or s.source<>''bibi_wallet'' or s.product_id<>p_product or s.quantity<>p_quantity)) then raise exception ''Transaction belongs to another purchase context.''; end if;');
 execute source;
end $patch$;
