-- Private build-only asset bucket used by Codemagic resource restoration.
-- Keep this separate from user-owned bibi-images and bibi-videos buckets.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bibi-build-assets',
  'bibi-build-assets',
  false,
  52428800,
  array['image/png','image/jpeg','image/gif','image/webp','video/mp4',
        'audio/mpeg','audio/mp4','font/ttf','font/otf','application/json',
        'text/plain','application/pdf']::text[]
)
on conflict (id) do update set
  name = excluded.name,
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
