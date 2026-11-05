-- Incremental A completion. Apply after comment-threading.sql; never replay schema.sql.
-- All writes remain behind the existing idempotent, account-serialized command.
create table if not exists public.bibi_cosmetics (
 user_id uuid not null,
 environment text not null,
 owned_ids text[] not null default '{}',
 equipped jsonb not null default '{}' check(jsonb_typeof(equipped)='object'),
 paid_challenge_ids text[] not null default '{}',
 primary key(user_id,environment),
 foreign key(user_id,environment) references public.bibi_wallets(user_id,environment) on delete cascade
);
alter table public.bibi_cosmetics enable row level security;
revoke all on public.bibi_cosmetics from anon,authenticated;
grant select on public.bibi_cosmetics to authenticated;
grant all on public.bibi_cosmetics to service_role;
drop policy if exists bibi_read on public.bibi_cosmetics;
create policy bibi_read on public.bibi_cosmetics for select to authenticated
 using(user_id=bibi_private.active_actor());

create table if not exists bibi_private.cosmetic_catalog (
 id text primary key, kind text not null, diamonds bigint not null check(diamonds>0)
);
alter table bibi_private.cosmetic_catalog enable row level security;
revoke all on bibi_private.cosmetic_catalog from public,anon,authenticated;
grant all on bibi_private.cosmetic_catalog to service_role;
drop policy if exists bibi_no_client_access on bibi_private.cosmetic_catalog;
create policy bibi_no_client_access on bibi_private.cosmetic_catalog for all to authenticated using(false) with check(false);
insert into bibi_private.cosmetic_catalog(id,kind,diamonds) values
 ('frame-sakura','avatarFrame',200),('frame-ice','avatarFrame',200),
 ('frame-violet','avatarFrame',500),('frame-gold','avatarFrame',500),
 ('ground-sakura','profileBackground',800),('ground-night','profileBackground',800),('ground-ice','profileBackground',800),
 ('bubble-sakura','chatBubble',300),('bubble-ink','chatBubble',300),('bubble-ice','chatBubble',300),
 ('chat-paper','chatBackground',600),('chat-dusk','chatBackground',600),
 ('cover-blossom','coverTemplate',400),('cover-night','coverTemplate',400),
 ('cover-gold','coverTemplate',400),('cover-ice','coverTemplate',400)
 on conflict(id) do nothing;
do $$ begin
 if exists(select 1 from bibi_private.cosmetic_catalog c join (values
  ('frame-sakura','avatarFrame',200),('frame-ice','avatarFrame',200),
  ('frame-violet','avatarFrame',500),('frame-gold','avatarFrame',500),
  ('ground-sakura','profileBackground',800),('ground-night','profileBackground',800),('ground-ice','profileBackground',800),
  ('bubble-sakura','chatBubble',300),('bubble-ink','chatBubble',300),('bubble-ice','chatBubble',300),
  ('chat-paper','chatBackground',600),('chat-dusk','chatBackground',600),
  ('cover-blossom','coverTemplate',400),('cover-night','coverTemplate',400),
  ('cover-gold','coverTemplate',400),('cover-ice','coverTemplate',400)
 ) expected(id,kind,diamonds) using(id) where c.kind<>expected.kind or c.diamonds<>expected.diamonds)
 then raise exception 'Existing cosmetic catalog differs from the approved client catalog.'; end if;
end $$;

-- A paid entry belongs to the wallet that funded it. Other environments cannot refund it.
create table if not exists bibi_private.challenge_payments (
 user_id uuid not null, challenge_id text not null references public.bibi_challenges(id),
 environment text not null, amount bigint not null check(amount=100),
 primary key(user_id,challenge_id),
 foreign key(user_id,environment) references public.bibi_wallets(user_id,environment) on delete cascade
);
alter table bibi_private.challenge_payments enable row level security;
revoke all on bibi_private.challenge_payments from public,anon,authenticated;
grant all on bibi_private.challenge_payments to service_role;
drop policy if exists bibi_no_client_access on bibi_private.challenge_payments;
create policy bibi_no_client_access on bibi_private.challenge_payments for all to authenticated using(false) with check(false);
create index if not exists bibi_challenge_payments_wallet_idx on bibi_private.challenge_payments(user_id,environment);
create index if not exists bibi_challenge_payments_challenge_idx on bibi_private.challenge_payments(challenge_id);

alter table public.bibi_wallet_activity add column if not exists item_id text;
alter table public.bibi_wallet_activity add column if not exists challenge_id text;
alter table public.bibi_wallet_activity drop constraint if exists bibi_wallet_activity_kind_check;
alter table public.bibi_wallet_activity add constraint bibi_wallet_activity_kind_check
 check(kind in ('credit','gift','reversal','unlock','challenge','refund'));

create or replace function bibi_private.cosmetic_command(p_operation uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid := bibi_private.active_actor(); env text := p_payload->>'environment';
 item bibi_private.cosmetic_catalog; state public.bibi_cosmetics; wallet public.bibi_wallets;
 item_id text := nullif(p_payload->>'item_id',''); kind text := p_payload->>'kind';
begin
 if actor is null or env is null or env not in ('Production','Sandbox') then
  raise exception 'An active account and wallet environment are required.' using errcode='42501';
 end if;
 select * into wallet from public.bibi_wallets where user_id=actor and environment=env for update;
 if not found then raise exception 'Wallet unavailable.'; end if;
 insert into public.bibi_cosmetics(user_id,environment) values(actor,env) on conflict do nothing;
 select * into state from public.bibi_cosmetics where user_id=actor and environment=env for update;
 if p_action='cosmetic_unlock' then
  select * into item from bibi_private.cosmetic_catalog where id=item_id;
  if not found then raise exception 'Look unavailable.'; end if;
  if not (item_id=any(state.owned_ids)) then
   if wallet.frozen or wallet.balance<item.diamonds then raise exception 'Insufficient available diamonds.'; end if;
   update public.bibi_wallets set balance=balance-item.diamonds where user_id=actor and environment=env;
   update public.bibi_cosmetics set owned_ids=array_append(owned_ids,item_id) where user_id=actor and environment=env;
   insert into public.bibi_wallet_activity(id,user_id,environment,kind,amount,item_id)
    values(p_operation,actor,env,'unlock',item.diamonds,item_id);
  end if;
  kind := item.kind;
 elsif p_action='cosmetic_equip' then
  if kind is null or kind not in ('avatarFrame','profileBackground','chatBubble','chatBackground','coverTemplate') then raise exception 'Look category unavailable.'; end if;
  if item_id is not null and (not (item_id=any(state.owned_ids)) or not exists(
   select 1 from bibi_private.cosmetic_catalog c where c.id=item_id and c.kind=kind)) then
   raise exception 'Unlock this look before using it.';
  end if;
 else raise exception 'Unsupported look action.';
 end if;
 update public.bibi_cosmetics set equipped=case when item_id is null then equipped-kind
  else jsonb_set(equipped,array[kind],to_jsonb(item_id)) end where user_id=actor and environment=env;
 return jsonb_build_object('saved',true);
end $$;
revoke all on function bibi_private.cosmetic_command(uuid,text,jsonb) from public,anon,authenticated;

-- Deleting the proof before crediting makes both explicit withdrawal and cascade
-- cleanup exactly-once. Account deletion does not resurrect a deleted wallet.
create or replace function bibi_private.refund_challenge(p_user uuid,p_challenge text)
returns void language plpgsql security definer set search_path='' as $$
declare payment bibi_private.challenge_payments;
begin
 delete from bibi_private.challenge_payments where user_id=p_user and challenge_id=p_challenge returning * into payment;
 if not found then return; end if;
 update public.bibi_wallets set balance=balance+payment.amount where user_id=p_user and environment=payment.environment;
 if not found then return; end if;
 update public.bibi_cosmetics set paid_challenge_ids=array_remove(paid_challenge_ids,p_challenge)
  where user_id=p_user and environment=payment.environment;
 insert into public.bibi_wallet_activity(user_id,environment,kind,amount,challenge_id)
  values(p_user,payment.environment,'refund',payment.amount,p_challenge);
end $$;
revoke all on function bibi_private.refund_challenge(uuid,text) from public,anon,authenticated;

create or replace function bibi_private.refund_deleted_entry()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform bibi_private.refund_challenge(old.user_id,old.challenge_id);
 return old;
end $$;
revoke all on function bibi_private.refund_deleted_entry() from public,anon,authenticated;
drop trigger if exists bibi_refund_deleted_entry on public.bibi_entries;
create trigger bibi_refund_deleted_entry after delete on public.bibi_entries
 for each row execute function bibi_private.refund_deleted_entry();

create or replace function bibi_private.withdraw_invalid_entries()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 delete from public.bibi_entries where video_id=new.id;
 return new;
end $$;
revoke all on function bibi_private.withdraw_invalid_entries() from public,anon,authenticated;
drop trigger if exists bibi_withdraw_invalid_entries on public.bibi_content;
create trigger bibi_withdraw_invalid_entries after update of withdrawn,removed on public.bibi_content
 for each row when (new.kind='video' and (new.withdrawn or new.removed)
  and (old.withdrawn is distinct from new.withdrawn or old.removed is distinct from new.removed))
 execute function bibi_private.withdraw_invalid_entries();

create or replace function bibi_private.challenge_payment(p_operation uuid,p_challenge text,p_environment text,p_selected boolean)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid := bibi_private.active_actor(); payment bibi_private.challenge_payments;
 wallet public.bibi_wallets;
begin
 if actor is null or p_environment is null or p_environment not in ('Production','Sandbox') then
  raise exception 'An active account and wallet environment are required.' using errcode='42501';
 end if;
 select * into payment from bibi_private.challenge_payments where user_id=actor and challenge_id=p_challenge;
 if found and payment.environment<>p_environment then raise exception 'Manage this entry with its original wallet environment.'; end if;
 if p_selected and payment.user_id is null then
  select * into wallet from public.bibi_wallets where user_id=actor and environment=p_environment for update;
  if not found or wallet.frozen or wallet.balance<100 then raise exception 'Joining a challenge costs 100 diamonds. No diamonds were spent.'; end if;
  update public.bibi_wallets set balance=balance-100 where user_id=actor and environment=p_environment;
  insert into bibi_private.challenge_payments values(actor,p_challenge,p_environment,100);
  insert into public.bibi_cosmetics(user_id,environment) values(actor,p_environment) on conflict do nothing;
  update public.bibi_cosmetics set paid_challenge_ids=array_append(paid_challenge_ids,p_challenge)
   where user_id=actor and environment=p_environment;
  insert into public.bibi_wallet_activity(id,user_id,environment,kind,amount,challenge_id)
   values(p_operation,actor,p_environment,'challenge',100,p_challenge);
 elsif not p_selected and payment.user_id is not null then
  perform bibi_private.refund_challenge(actor,p_challenge);
 end if;
end $$;
revoke all on function bibi_private.challenge_payment(uuid,text,text,boolean) from public,anon,authenticated;

-- Patch only known deployed command fragments; fail atomically on schema drift.
do $patch$
declare source text := pg_get_functiondef('bibi_private.command(uuid,text,jsonb)'::regprocedure);
 old text;
begin
 if position('set reply_to=' in source)=0 then raise exception 'Expected deployed comment-threading support was not found.'; end if;
 old := substring(source from E' when ''gift'' then\\n.*? else raise exception ''Unsupported action\\.'';');
 if old is null then raise exception 'Expected gift branch was not found.'; end if;
 source := replace(source,old,E' when ''gift'' then\n   raise exception ''Post gifts are no longer available. No diamonds were spent.'';\n else raise exception ''Unsupported action.'';');
 old := 'update public.bibi_reports set hidden=false where user_id=actor and content_id=target;';
 if position(old in source)>0 then
  source := replace(source,old,
   'update public.bibi_reports set hidden=false where user_id=actor and ((target is not null and content_id=target) or (target is null and content_id is null and target_id=nullif(p_payload->>''user_id'','''')::uuid));');
 elsif position('target_id=nullif(p_payload->>''user_id'','''')::uuid' in source)=0 then
  raise exception 'Expected report unhide branch was not found.';
 end if;
 if position(' when ''cosmetic_unlock'',''cosmetic_equip'' then' in source)=0 then
  old := E' case p_action\n when ''profile'' then';
  if position(old in source)=0 then raise exception 'Expected action dispatcher was not found.'; end if;
  source := replace(source,old,E' case p_action\n when ''cosmetic_unlock'',''cosmetic_equip'' then\n   result_value := bibi_private.cosmetic_command(p_operation,p_action,p_payload);\n when ''profile'' then');
  old := 'insert into public.bibi_entries(id,user_id,challenge_id,video_id) values(p_operation,actor,p_payload->>''challenge_id'',record_id)';
  if position(old in source)=0 then raise exception 'Expected challenge publication was not found.'; end if;
  source := replace(source,old,'perform bibi_private.challenge_payment(p_operation,p_payload->>''challenge_id'',p_payload->>''environment'',true); '||old);
  old := 'insert into public.bibi_entries(id,user_id,challenge_id,video_id) values(p_operation,actor,p_payload->>''challenge_id'',target)';
  if position(old in source)=0 then raise exception 'Expected challenge entry was not found.'; end if;
  source := replace(source,old,'perform bibi_private.challenge_payment(p_operation,p_payload->>''challenge_id'',p_payload->>''environment'',true); '||old);
  old := 'else delete from public.bibi_entries where user_id=actor and challenge_id=p_payload->>''challenge_id''; end if;';
  if position(old in source)=0 then raise exception 'Expected challenge withdrawal was not found.'; end if;
  source := replace(source,old,'else perform bibi_private.challenge_payment(p_operation,p_payload->>''challenge_id'',p_payload->>''environment'',false); delete from public.bibi_entries where user_id=actor and challenge_id=p_payload->>''challenge_id''; end if;');
 end if;
 execute source;
end $patch$;
