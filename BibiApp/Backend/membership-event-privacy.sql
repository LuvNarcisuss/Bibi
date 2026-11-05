-- Preserve membership reads/upserts while removing relationship keys from the
-- DEFAULT replica identity used in Postgres Changes DELETE metadata.
-- Existing rows receive stable opaque IDs; no memberships or state are removed.
do $$ begin
 if exists(select 1 from pg_constraint
  where confrelid='public.bibi_conversation_members'::regclass and contype='f') then
  raise exception 'Membership primary key is referenced; review required.';
 end if;
 if (select relreplident from pg_class where oid='public.bibi_conversation_members'::regclass)<>'d' then
  raise exception 'Unexpected membership replica identity; review required.';
 end if;
end $$;
alter table public.bibi_conversation_members add column if not exists id uuid not null default gen_random_uuid();
alter table public.bibi_conversation_members add constraint bibi_conversation_members_conversation_user_key
 unique(conversation_id,user_id);
alter table public.bibi_conversation_members drop constraint bibi_conversation_members_pkey;
alter table public.bibi_conversation_members add constraint bibi_conversation_members_pkey primary key(id);
notify pgrst,'reload schema';
