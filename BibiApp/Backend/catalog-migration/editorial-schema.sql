-- Additive editorial identities have no Auth account and cannot receive private messages.
alter table public.bibi_media alter column owner_id drop not null;
alter table public.bibi_media add column editorial boolean not null default false;
alter table public.bibi_media add column sha256 text;
alter table public.bibi_media drop constraint bibi_media_check;
alter table public.bibi_media add constraint bibi_media_ownership_path_check check (
  (not editorial and owner_id is not null and object_path = owner_id::text || '/' || id::text)
  or (editorial and owner_id is null and sha256 ~ '^[0-9a-f]{64}$' and object_path = 'catalog-v1/' || sha256)
);
create table public.bibi_editorial_profiles (
  id text primary key check (id like 'bibi-story:%' or id = 'bibi-editor'),
  display_name text not null check (char_length(display_name) between 1 and 48),
  biography text not null check (char_length(biography) <= 500),
  avatar_media_id uuid references public.bibi_media(id) on delete restrict
);
alter table public.bibi_editorial_profiles enable row level security;
revoke all on public.bibi_editorial_profiles from public, anon, authenticated;
grant select on public.bibi_editorial_profiles to authenticated;
grant all on public.bibi_editorial_profiles to service_role;
create policy bibi_editorial_read on public.bibi_editorial_profiles for select to authenticated
using ((select bibi_private.active_actor()) is not null);
alter table public.bibi_content add column editorial_profile_id text references public.bibi_editorial_profiles(id) on delete restrict;
alter table public.bibi_content add constraint bibi_editorial_identity_check check (
  editorial_profile_id is null or (editorial and owner_id is null)
);
alter table public.bibi_content_revisions add column cover_media_id uuid references public.bibi_media(id) on delete restrict;
alter table public.bibi_content_revisions add column source_url text;
alter table public.bibi_content_revisions add column credit text;
alter table public.bibi_content_revisions add column collection_generation integer;
alter table public.bibi_circles add column artwork_media_id uuid references public.bibi_media(id) on delete restrict;
alter table public.bibi_challenges add column artwork_media_id uuid references public.bibi_media(id) on delete restrict;
create index bibi_content_editorial_profile_idx on public.bibi_content(editorial_profile_id);
create index bibi_revisions_cover_media_idx on public.bibi_content_revisions(cover_media_id);
create index bibi_editorial_avatar_media_idx on public.bibi_editorial_profiles(avatar_media_id);
create index bibi_circles_artwork_media_idx on public.bibi_circles(artwork_media_id);
create index bibi_challenges_artwork_media_idx on public.bibi_challenges(artwork_media_id);
create or replace function bibi_private.can_read_media(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.bibi_media m
 where m.id=target and bibi_private.active_actor() is not null and (
 m.owner_id=bibi_private.active_actor() or (m.status='ready' and (
 exists(select 1 from public.bibi_content c join public.bibi_content_revisions r on r.id=c.approved_revision
 where (r.media_id=m.id or r.cover_media_id=m.id) and bibi_private.can_read_content(c.id))
 or (m.editorial and (
 exists(select 1 from public.bibi_editorial_profiles p where p.avatar_media_id=m.id)
 or exists(select 1 from public.bibi_circles c where c.active and c.artwork_media_id=m.id)
 or exists(select 1 from public.bibi_challenges c where c.active and c.artwork_media_id=m.id)
 ))))))
$$;
