-- Add only public-key invalidation metadata. Existing publication members remain.
-- Relationship tables are deliberately omitted: their DELETE primary keys reveal
-- private user-target edges and Postgres Changes does not apply row RLS to DELETE.
do $$
declare name text;
begin
 foreach name in array array['bibi_content_revisions','bibi_conversations','bibi_profiles'] loop
  if not exists(select 1 from pg_publication_tables
   where pubname='supabase_realtime' and schemaname='public' and tablename=name) then
   execute format('alter publication supabase_realtime add table public.%I',name);
  end if;
 end loop;
end $$;
