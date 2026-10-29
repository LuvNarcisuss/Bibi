-- Guest eligibility retains consent, live-session, status and ownership checks.
create or replace function bibi_private.active_actor() returns uuid
language sql stable security definer set search_path = '' as $$
 select p.id from public.bibi_profiles p
 join public.bibi_consents c on c.user_id=p.id and c.adult_declared
 join auth.users u on u.id=p.id and (u.is_anonymous is true or u.email_confirmed_at is not null)
 where p.id=auth.uid() and p.account_status='active'
 and exists(select 1 from auth.sessions s where s.id::text=auth.jwt()->>'session_id' and s.user_id=p.id)
$$;

create or replace function bibi_private.enroll(p_version text,p_adult boolean,p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
 if actor is null or p_adult is distinct from true or p_version is null or p_version='unavailable'
 or char_length(p_version) not between 1 and 200 or char_length(trim(p_name)) not between 1 and 48
 or not exists(select 1 from auth.users where id=actor and (is_anonymous is true or email_confirmed_at is not null))
 or not exists(select 1 from auth.sessions where id::text=auth.jwt()->>'session_id' and user_id=actor)
 then raise exception 'An authenticated account, adult declaration, and current agreement are required.' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 if exists(select 1 from public.bibi_profiles where id=actor and account_status<>'active') then
 raise exception 'Account unavailable.' using errcode='42501'; end if;
 insert into public.bibi_profiles(id,display_name) values(actor,trim(p_name)) on conflict(id) do nothing;
 insert into public.bibi_consents(user_id,agreement_version,adult_declared) values(actor,p_version,true)
 on conflict(user_id) do update set agreement_version=excluded.agreement_version,accepted_at=now();
 insert into public.bibi_wallets(user_id,environment) values(actor,'Production'),(actor,'Sandbox') on conflict do nothing;
 return jsonb_build_object('user_id',actor);
end $$;
