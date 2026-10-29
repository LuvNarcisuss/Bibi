-- Atomic composed actions and client completion policies.
alter table public.bibi_reports add column hidden boolean not null default true;
create or replace function bibi_private.can_read_content(target uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
 return exists(select 1 from public.bibi_content c where c.id=target and bibi_private.active_actor() is not null
 and (c.owner_id=bibi_private.active_actor() or
 (c.approved_revision is not null and not c.withdrawn and not c.removed
 and not bibi_private.blocked(bibi_private.active_actor(),c.owner_id)
 and (c.parent_id is null or bibi_private.can_read_content(c.parent_id))
 and not exists(select 1 from public.bibi_reports r where r.user_id=bibi_private.active_actor() and r.content_id=c.id and r.hidden))))
;
end $$;
-- Invitation metadata is readable by its recipient; messages still require active membership.
drop policy bibi_read on public.bibi_conversations;
create policy bibi_read on public.bibi_conversations for select to authenticated using (
 bibi_private.can_read_conversation(id) or (kind='group' and owner_id is not null
 and not bibi_private.blocked(bibi_private.active_actor(),owner_id)
 and exists(select 1 from public.bibi_conversation_members m where m.conversation_id=id
 and m.user_id=bibi_private.active_actor() and m.status='invited')));

create function bibi_private.profile_counts(p_user uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
 select jsonb_build_object(
 'following',(select count(*) from public.bibi_follows where user_id=p_user),
 'followers',(select count(*) from public.bibi_follows where target_id=p_user))
 where bibi_private.active_actor() is not null and not bibi_private.blocked(bibi_private.active_actor(),p_user)
 and exists(select 1 from public.bibi_profiles where id=p_user and account_status='active')
$$;
create function public.bibi_profile_counts(p_user uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$ select bibi_private.profile_counts(p_user) $$;
revoke all on function bibi_private.profile_counts(uuid),public.bibi_profile_counts(uuid) from public,anon;
grant execute on function bibi_private.profile_counts(uuid),public.bibi_profile_counts(uuid) to authenticated;
