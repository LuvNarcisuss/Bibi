-- A signed revocation must survive notification-before-credit ordering.
create table bibi_private.apple_revocations (
 transaction_id text not null, environment text not null check(environment in ('Sandbox','Production')),
 received_at timestamptz not null default now(), primary key(transaction_id,environment)
);
alter table bibi_private.apple_revocations enable row level security;
revoke all on bibi_private.apple_revocations from public,anon,authenticated;
grant all on bibi_private.apple_revocations to service_role;
create policy bibi_no_client_access on bibi_private.apple_revocations for all to authenticated using(false) with check(false);
create or replace function bibi_private.credit_purchase(p_user uuid,p_transaction text,p_environment text,p_product text,p_quantity integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior bibi_private.apple_transactions; amount bigint; current_balance bigint;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 if p_environment not in ('Sandbox','Production') or p_quantity is null or p_quantity not between 1 and 10
 or p_transaction is null or char_length(p_transaction) not between 1 and 100
 or not exists(select 1 from public.bibi_profiles where id=p_user and account_status='active') then raise exception 'Purchase unavailable.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_environment||':'||p_transaction,2));
 if exists(select 1 from bibi_private.apple_revocations where transaction_id=p_transaction and environment=p_environment) then raise exception 'Transaction has been revoked.'; end if;
 select * into prior from bibi_private.apple_transactions where transaction_id=p_transaction and environment=p_environment;
 if found then
   if prior.user_id<>p_user or prior.product_id<>p_product or prior.quantity<>p_quantity or prior.revoked then raise exception 'Transaction cannot be credited.'; end if;
 else
   select diamonds*p_quantity into amount from bibi_private.products where id=p_product;
   if amount is null then raise exception 'Product unavailable.'; end if;
   insert into public.bibi_wallets(user_id,environment) values(p_user,p_environment) on conflict do nothing;
   perform 1 from public.bibi_wallets where user_id=p_user and environment=p_environment for update;
   insert into bibi_private.apple_transactions(transaction_id,environment,user_id,product_id,quantity,amount)
     values(p_transaction,p_environment,p_user,p_product,p_quantity,amount);
   update public.bibi_wallets set balance=balance+amount where user_id=p_user and environment=p_environment;
   insert into public.bibi_wallet_activity(user_id,environment,kind,amount,transaction_id)
     values(p_user,p_environment,'credit',amount,p_transaction);
 end if;
 select balance into current_balance from public.bibi_wallets where user_id=p_user and environment=p_environment;
 return jsonb_build_object('transaction_id',p_transaction,'balance',current_balance,'environment',p_environment);
end $$;
create or replace function bibi_private.revoke_purchase(p_transaction text,p_environment text) returns void
language plpgsql security definer set search_path='' as $$
declare item bibi_private.apple_transactions; current_balance bigint;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_environment||':'||p_transaction,2));
 if p_environment not in ('Sandbox','Production') or p_transaction is null or char_length(p_transaction) not between 1 and 100 then raise exception 'Invalid transaction.'; end if;
 insert into bibi_private.apple_revocations(transaction_id,environment) values(p_transaction,p_environment) on conflict do nothing;
 select * into item from bibi_private.apple_transactions where transaction_id=p_transaction and environment=p_environment for update;
 if not found or item.revoked then return; end if;
 select balance into current_balance from public.bibi_wallets where user_id=item.user_id and environment=p_environment for update;
 update bibi_private.apple_transactions set revoked=true where transaction_id=p_transaction and environment=p_environment;
 if current_balance is not null then
   update public.bibi_wallets set balance=greatest(0,balance-item.amount),frozen=frozen or balance<item.amount
     where user_id=item.user_id and environment=p_environment;
   insert into public.bibi_wallet_activity(user_id,environment,kind,amount,transaction_id)
     values(item.user_id,p_environment,'reversal',item.amount,p_transaction);
 end if;
end $$;
