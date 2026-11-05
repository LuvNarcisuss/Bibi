-- PostgreSQL CHECK constraints accept UNKNOWN; explicitly reject missing hashes.
alter table public.bibi_media add constraint bibi_editorial_sha256_required check (not editorial or sha256 is not null);
