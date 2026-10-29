-- Bibi authoritative backend. Additive initial deployment; no legacy data import.
create schema if not exists bibi_private;
revoke all on schema bibi_private from public, anon;
grant usage on schema bibi_private to authenticated, service_role;
alter default privileges in schema bibi_private revoke execute on functions from public;

create table public.bibi_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 48),
  biography text not null default '' check (char_length(biography) <= 500),
  account_status text not null default 'active' check (account_status in ('active','deleting','suspended')),
  created_at timestamptz not null default now()
);
create table public.bibi_consents (
  user_id uuid primary key references public.bibi_profiles(id) on delete cascade,
  agreement_version text not null check (char_length(agreement_version) between 1 and 200),
  adult_declared boolean not null check (adult_declared),
  accepted_at timestamptz not null default now()
);
create table public.bibi_circles (
  id text primary key, title text not null, subtitle text not null, prompt text not null,
  artwork text not null, active boolean not null default true
);
create table public.bibi_challenges (
  id text primary key, title text not null, category text not null, summary text not null,
  artwork text not null, steps jsonb not null, active boolean not null default true
);
create table public.bibi_circle_members (
  circle_id text references public.bibi_circles(id),
  user_id uuid references public.bibi_profiles(id) on delete cascade,
  created_at timestamptz not null default now(), primary key (circle_id,user_id)
);
create table public.bibi_follows (
  user_id uuid references public.bibi_profiles(id) on delete cascade,
  target_id uuid references public.bibi_profiles(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,target_id), check(user_id <> target_id)
);
create table public.bibi_blocks (
  user_id uuid references public.bibi_profiles(id) on delete cascade,
  target_id uuid references public.bibi_profiles(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,target_id), check(user_id <> target_id)
);
create table public.bibi_media (
  id uuid primary key, owner_id uuid not null references public.bibi_profiles(id) on delete cascade,
  bucket_id text not null check(bucket_id in ('bibi-images','bibi-videos')),
  object_path text not null, mime_type text not null,
  status text not null default 'uploading' check(status in ('uploading','ready','removed')),
  byte_count bigint, duration_seconds numeric,
  created_at timestamptz not null default now(), unique(bucket_id,object_path),
  check(object_path = owner_id::text || '/' || id::text),
  check(byte_count is null or byte_count between 1 and 50000000),
  check(duration_seconds is null or duration_seconds > 0 and duration_seconds <= 180)
);
create table public.bibi_content (
  id uuid primary key, owner_id uuid references public.bibi_profiles(id) on delete cascade,
  kind text not null check(kind in ('video','post','comment','reply','avatar')),
  circle_id text references public.bibi_circles(id),
  parent_id uuid references public.bibi_content(id) on delete cascade,
  approved_revision uuid, pending_revision uuid,
  editorial boolean not null default false,
  withdrawn boolean not null default false, removed boolean not null default false,
  created_at timestamptz not null default now(),
  check(owner_id is not null or editorial), check(parent_id is distinct from id)
);
create table public.bibi_content_revisions (
  id uuid primary key, content_id uuid not null references public.bibi_content(id) on delete cascade,
  title text not null default '' check(char_length(title) <= 120),
  body text not null default '' check(char_length(body) <= 2000),
  media_id uuid references public.bibi_media(id) on delete set null,
  video_id uuid references public.bibi_content(id) on delete set null,
  status text not null check(status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(), unique(content_id,id)
);
alter table public.bibi_content add constraint bibi_approved_revision_fk
  foreign key(id,approved_revision) references public.bibi_content_revisions(content_id,id) deferrable initially deferred;
alter table public.bibi_content add constraint bibi_pending_revision_fk
  foreign key(id,pending_revision) references public.bibi_content_revisions(content_id,id) deferrable initially deferred;
create table public.bibi_saved (
  user_id uuid references public.bibi_profiles(id) on delete cascade,
  content_id uuid references public.bibi_content(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,content_id)
);
create table public.bibi_likes (
  user_id uuid references public.bibi_profiles(id) on delete cascade,
  content_id uuid references public.bibi_content(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,content_id)
);
create table public.bibi_shares (
  id uuid primary key, user_id uuid references public.bibi_profiles(id) on delete cascade,
  content_id uuid references public.bibi_content(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table public.bibi_entries (
  id uuid primary key, user_id uuid not null references public.bibi_profiles(id) on delete cascade,
  challenge_id text not null references public.bibi_challenges(id),
  video_id uuid not null references public.bibi_content(id) on delete cascade,
  created_at timestamptz not null default now(), unique(user_id,challenge_id)
);
create table public.bibi_reports (
  id uuid primary key, user_id uuid not null references public.bibi_profiles(id) on delete cascade,
  content_id uuid references public.bibi_content(id) on delete set null,
  target_id uuid references public.bibi_profiles(id) on delete set null,
  reason text not null check(char_length(reason) between 1 and 120),
  details text not null default '' check(char_length(details) <= 2000),
  status text not null default 'submitted' check(status in ('submitted','reviewed','resolved')),
  created_at timestamptz not null default now()
);
create table public.bibi_conversations (
  id uuid primary key, kind text not null check(kind in ('direct','group')),
  owner_id uuid references public.bibi_profiles(id) on delete set null,
  title text not null default '' check(char_length(title) <= 80),
  direct_pair text unique, created_at timestamptz not null default now(),
  check((kind='direct') = (direct_pair is not null))
);
create table public.bibi_conversation_members (
  conversation_id uuid references public.bibi_conversations(id) on delete cascade,
  user_id uuid references public.bibi_profiles(id) on delete cascade,
  status text not null check(status in ('invited','active','left')),
  joined_at timestamptz, joined_sequence bigint not null default 0, read_sequence bigint not null default 0 check(read_sequence >= 0),
  pinned boolean not null default false, muted boolean not null default false,
  hidden boolean not null default false, primary key(conversation_id,user_id)
);
create table public.bibi_messages (
  id uuid primary key, conversation_id uuid not null references public.bibi_conversations(id) on delete cascade,
  sender_id uuid references public.bibi_profiles(id) on delete set null,
  body text not null check(char_length(body) between 1 and 2000),
  sequence bigint generated always as identity unique,
  created_at timestamptz not null default now()
);
create table public.bibi_wallets (
  user_id uuid references public.bibi_profiles(id) on delete cascade,
  environment text check(environment in ('Sandbox','Production')),
  balance bigint not null default 0 check(balance >= 0), frozen boolean not null default false,
  primary key(user_id,environment)
);
create table public.bibi_wallet_activity (
  id uuid primary key default gen_random_uuid(), user_id uuid not null,
  environment text not null, kind text not null check(kind in ('credit','gift','reversal')),
  amount bigint not null check(amount > 0), transaction_id text,
  post_id uuid, gift_id text, quantity integer, created_at timestamptz not null default now(),
  foreign key(user_id,environment) references public.bibi_wallets(user_id,environment) on delete cascade
);
create table bibi_private.operations (
  user_id uuid references public.bibi_profiles(id) on delete cascade, id uuid,
  action text not null, payload jsonb not null, result jsonb, primary key(user_id,id)
);
create table bibi_private.apple_transactions (
  transaction_id text not null, environment text not null,
  user_id uuid not null, product_id text not null, quantity integer not null check(quantity>0),
  amount bigint not null check(amount>0), revoked boolean not null default false,
  created_at timestamptz not null default now(), primary key(transaction_id,environment)
);
create table bibi_private.deletion_jobs (
  user_id uuid primary key, requested_at timestamptz not null default now(),
  completed_at timestamptz, error_code text
);
create table bibi_private.products (id text primary key, diamonds bigint not null check(diamonds>0));
create table bibi_private.gifts (id text primary key, diamonds bigint not null check(diamonds>0));
insert into bibi_private.products values
 ('ldbsrbbhebevxdjf',400),('fxvrdbmlwopeasti',800),('akafhhbydyymfpzk',2450),
 ('ffzwgpuvsyyhaeeg',5150),('ofgjvlbwtzchgvbx',10800),('azacbzpzvvvpblzu',29400),('lghwqjsuuxivrdrf',63700);
insert into bibi_private.gifts values
 ('rose',10),('balloons',50),('heart',100),('beat',200),('spotlight',500),
 ('bouquet',1000),('crown',2000),('encore',5000),('galaxy',10000);

create index on public.bibi_circle_members(user_id);
create index on public.bibi_follows(target_id);
create index on public.bibi_blocks(target_id);
create index on public.bibi_media(owner_id,created_at);
create index on public.bibi_content(owner_id,created_at desc,id);
create index on public.bibi_content(kind,created_at desc,id);
create index on public.bibi_content(circle_id);
create index on public.bibi_content(parent_id);
create index on public.bibi_content_revisions(media_id);
create index on public.bibi_content_revisions(video_id);
create index on public.bibi_saved(content_id);
create index on public.bibi_likes(content_id);
create index on public.bibi_shares(content_id);
create index on public.bibi_shares(user_id);
create index on public.bibi_entries(video_id);
create index on public.bibi_entries(challenge_id);
create index on public.bibi_reports(user_id);
create index on public.bibi_reports(content_id);
create index on public.bibi_reports(target_id);
create index on public.bibi_conversations(owner_id);
create index on public.bibi_conversation_members(user_id,status);
create index on public.bibi_messages(conversation_id,sequence);
create index on public.bibi_messages(sender_id);
create index on public.bibi_wallet_activity(user_id,environment,created_at desc);
create index on bibi_private.apple_transactions(user_id);

create function bibi_private.active_actor() returns uuid
language sql stable security definer set search_path = '' as $$
 select p.id from public.bibi_profiles p
 join public.bibi_consents c on c.user_id=p.id and c.adult_declared
 join auth.users u on u.id=p.id and u.email_confirmed_at is not null
 where p.id=auth.uid() and p.account_status='active'
 and exists(select 1 from auth.sessions s where s.id::text=auth.jwt()->>'session_id' and s.user_id=p.id)
$$;
create function bibi_private.blocked(a uuid,b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.bibi_blocks where (user_id=a and target_id=b) or (user_id=b and target_id=a))
$$;
create function bibi_private.can_read_content(target uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
 return exists(select 1 from public.bibi_content c where c.id=target and bibi_private.active_actor() is not null
 and (c.owner_id=bibi_private.active_actor() or
 (c.approved_revision is not null and not c.withdrawn and not c.removed
 and not bibi_private.blocked(bibi_private.active_actor(),c.owner_id)
 and (c.parent_id is null or bibi_private.can_read_content(c.parent_id))
 and not exists(select 1 from public.bibi_reports r where r.user_id=bibi_private.active_actor() and r.content_id=c.id))))
;
end $$;
create function bibi_private.can_read_conversation(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.bibi_conversation_members m
 join public.bibi_conversations c on c.id=m.conversation_id
 where m.conversation_id=target and m.user_id=bibi_private.active_actor() and m.status='active'
 and (c.kind='group' or not exists(select 1 from public.bibi_conversation_members other
 where other.conversation_id=target and bibi_private.blocked(m.user_id,other.user_id))))
$$;
create function bibi_private.can_read_media(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.bibi_media m where m.id=target and bibi_private.active_actor() is not null
 and (m.owner_id=bibi_private.active_actor() or (m.status='ready' and exists(
 select 1 from public.bibi_content c join public.bibi_content_revisions r on r.id=c.approved_revision
 where r.media_id=m.id and bibi_private.can_read_content(c.id)))))
$$;

-- Clients can read permitted rows. All writes pass through checked commands.
create function bibi_private.enroll(p_version text,p_adult boolean,p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
 if actor is null or p_adult is distinct from true or p_version is null or p_version='unavailable'
 or char_length(p_version) not between 1 and 200 or char_length(trim(p_name)) not between 1 and 48
 or not exists(select 1 from auth.users where id=actor and email_confirmed_at is not null)
 or not exists(select 1 from auth.sessions where id::text=auth.jwt()->>'session_id' and user_id=actor)
 then raise exception 'A verified account, adult declaration, and current agreement are required.' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 if exists(select 1 from public.bibi_profiles where id=actor and account_status<>'active') then
 raise exception 'Account unavailable.' using errcode='42501'; end if;
 insert into public.bibi_profiles(id,display_name) values(actor,trim(p_name)) on conflict(id) do nothing;
 insert into public.bibi_consents(user_id,agreement_version,adult_declared) values(actor,p_version,true)
 on conflict(user_id) do update set agreement_version=excluded.agreement_version,accepted_at=now();
 insert into public.bibi_wallets(user_id,environment) values(actor,'Production'),(actor,'Sandbox') on conflict do nothing;
 return jsonb_build_object('user_id',actor);
end $$;
create function public.bibi_enroll(p_version text,p_adult boolean,p_name text) returns jsonb
language sql security invoker set search_path = '' as $$ select bibi_private.enroll(p_version,p_adult,p_name) $$;

create function bibi_private.command(p_operation uuid,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
 actor uuid := bibi_private.active_actor(); prior bibi_private.operations;
 target uuid; record_id uuid; revision_id uuid; media uuid; parent uuid; peer uuid;
 item public.bibi_content; room public.bibi_conversations; wallet public.bibi_wallets;
 result_value jsonb := '{}'::jsonb; amount bigint; price bigint; qty integer;
 body text; kind text; env text; pair text; selected boolean;
begin
 if actor is null or p_operation is null or p_payload is null or jsonb_typeof(p_payload)<>'object'
 then raise exception 'Sign in to continue.' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 if bibi_private.active_actor() is distinct from actor then raise exception 'Account unavailable.' using errcode='42501'; end if;
 select * into prior from bibi_private.operations where user_id=actor and id=p_operation;
 if found then
   if prior.action<>p_action or prior.payload<>p_payload then raise exception 'Operation payload changed.'; end if;
   return prior.result;
 end if;
 insert into bibi_private.operations(user_id,id,action,payload) values(actor,p_operation,p_action,p_payload);
 target := nullif(p_payload->>'target_id','')::uuid;
 selected := coalesce((p_payload->>'selected')::boolean,true);
 case p_action
 when 'profile' then
   update public.bibi_profiles set display_name=trim(p_payload->>'display_name'),biography=coalesce(p_payload->>'biography','') where id=actor;
 when 'circle' then
   if not exists(select 1 from public.bibi_circles where id=p_payload->>'circle_id' and active) then raise exception 'Circle unavailable.'; end if;
   if selected then insert into public.bibi_circle_members values(p_payload->>'circle_id',actor,now()) on conflict do nothing;
   else delete from public.bibi_circle_members where circle_id=p_payload->>'circle_id' and user_id=actor; end if;
 when 'follow' then
   perform pg_advisory_xact_lock(hashtextextended(least(actor::text,target::text)||':'||greatest(actor::text,target::text),1));
   if target=actor or bibi_private.blocked(actor,target) or not exists(select 1 from public.bibi_profiles where id=target and account_status='active') then raise exception 'Profile unavailable.'; end if;
   if selected then insert into public.bibi_follows values(actor,target,now()) on conflict do nothing;
   else delete from public.bibi_follows where user_id=actor and target_id=target; end if;
 when 'block' then
   perform pg_advisory_xact_lock(hashtextextended(least(actor::text,target::text)||':'||greatest(actor::text,target::text),1));
   if target=actor then raise exception 'Cannot block your account.'; end if;
   if selected then
     insert into public.bibi_blocks values(actor,target,now()) on conflict do nothing;
     delete from public.bibi_follows where (user_id=actor and target_id=target) or (user_id=target and target_id=actor);
   else delete from public.bibi_blocks where user_id=actor and target_id=target; end if;
 when 'save','like','share' then
   if not bibi_private.can_read_content(target) then raise exception 'Content unavailable.'; end if;
   if p_action='save' then
     if selected then insert into public.bibi_saved values(actor,target,now()) on conflict do nothing;
     else delete from public.bibi_saved where user_id=actor and content_id=target; end if;
   elsif p_action='like' then
     if selected then insert into public.bibi_likes values(actor,target,now()) on conflict do nothing;
     else delete from public.bibi_likes where user_id=actor and content_id=target; end if;
   else insert into public.bibi_shares(id,user_id,content_id) values(p_operation,actor,target); end if;
 when 'stage_media' then
   record_id := p_operation;
   kind := p_payload->>'mime_type';
   if kind not in ('image/jpeg','image/png','video/mp4') then raise exception 'Unsupported media type.'; end if;
   insert into public.bibi_media(id,owner_id,bucket_id,object_path,mime_type)
   values(record_id,actor,case when kind='video/mp4' then 'bibi-videos' else 'bibi-images' end,actor::text || '/' || record_id::text,kind);
   select to_jsonb(m) into result_value from public.bibi_media m where id=record_id;
 when 'publish' then
   kind := p_payload->>'kind'; body := trim(coalesce(p_payload->>'body',''));
   media := nullif(p_payload->>'media_id','')::uuid;
   parent := nullif(p_payload->>'parent_id','')::uuid;
   if kind not in ('video','post','comment','reply','avatar') then raise exception 'Unsupported content.'; end if;
   if kind in ('comment','reply') and (media is not null or nullif(p_payload->>'video_id','') is not null) then raise exception 'Replies must contain text only.'; end if;
   if kind in ('video','post','avatar') and parent is not null then raise exception 'Invalid content parent.'; end if;
   if kind='post' and (char_length(body) not between 1 and 1000 or not exists(select 1 from public.bibi_circle_members where user_id=actor and circle_id=p_payload->>'circle_id')) then raise exception 'Join the circle and write up to 1,000 characters.'; end if;
   if kind in ('comment','reply') and (char_length(body) not between 1 and case when kind='reply' then 500 else 200 end or not bibi_private.can_read_content(parent)) then raise exception 'Reply unavailable.'; end if;
   if kind='comment' and not exists(select 1 from public.bibi_content where id=parent and kind='video') then raise exception 'Video unavailable.'; end if;
   if kind='reply' and not exists(select 1 from public.bibi_content where id=parent and kind='post') then raise exception 'Post unavailable.'; end if;
   if kind in ('video','avatar') and media is null then raise exception 'Media required.'; end if;
   if media is not null and not exists(select 1 from public.bibi_media where id=media and owner_id=actor and status='ready'
     and (case when kind='video' then mime_type='video/mp4' and duration_seconds between 0.01 and 180 else mime_type in ('image/jpeg','image/png') and byte_count<=1000000 end)) then raise exception 'Upload is not ready.'; end if;
   peer := nullif(p_payload->>'video_id','')::uuid;
   if peer is not null and (not bibi_private.can_read_content(peer) or not exists(select 1 from public.bibi_content where id=peer and kind='video')) then raise exception 'Attached video unavailable.'; end if;
   record_id := coalesce(target,p_operation); revision_id := p_operation;
   if target is null then
     if kind='post' and (select count(*) from public.bibi_content where owner_id=actor and kind='post')>=100 then raise exception 'Post limit reached.'; end if;
     if kind='reply' and (select count(*) from public.bibi_content where owner_id=actor and kind='reply')>=2000 then raise exception 'Reply limit reached.'; end if;
     insert into public.bibi_content(id,owner_id,kind,circle_id,parent_id)
       values(record_id,actor,kind,case when kind='post' then p_payload->>'circle_id' end,parent);
   else
     select * into item from public.bibi_content where id=target for update;
     if not found or item.owner_id is distinct from actor or item.editorial or item.kind<>kind or item.removed then raise exception 'Content unavailable.'; end if;
     if item.parent_id is distinct from parent or item.circle_id is distinct from (case when kind='post' then p_payload->>'circle_id' end) then raise exception 'Content identity cannot change.'; end if;
   end if;
   insert into public.bibi_content_revisions(id,content_id,title,body,media_id,video_id,status)
     values(revision_id,record_id,coalesce(p_payload->>'title',''),body,media,peer,case when kind in ('reply','comment') then 'approved' else 'pending' end);
   update public.bibi_content set pending_revision=case when kind in ('reply','comment') then null else revision_id end,
     approved_revision=case when kind in ('reply','comment') then revision_id else approved_revision end,
     withdrawn=false where id=record_id;
   result_value := jsonb_build_object('id',record_id,'revision_id',revision_id,'status',case when kind in ('reply','comment') then 'published' else 'pending' end);
 when 'withdraw' then
   update public.bibi_content set withdrawn=true where id=target and owner_id=actor;
   if not found then raise exception 'Content unavailable.'; end if;
 when 'challenge' then
   if selected then
     if not exists(select 1 from public.bibi_content c join public.bibi_media m on m.id=(select media_id from public.bibi_content_revisions where id=coalesce(c.pending_revision,c.approved_revision))
       where c.id=target and c.owner_id=actor and c.kind='video' and not c.removed and not c.withdrawn and m.duration_seconds between 0.01 and 180)
       or not exists(select 1 from public.bibi_challenges where id=p_payload->>'challenge_id' and active) then raise exception 'Choose your own eligible video.'; end if;
     insert into public.bibi_entries(id,user_id,challenge_id,video_id) values(p_operation,actor,p_payload->>'challenge_id',target)
       on conflict(user_id,challenge_id) do update set video_id=excluded.video_id,created_at=now();
   else delete from public.bibi_entries where user_id=actor and challenge_id=p_payload->>'challenge_id'; end if;
 when 'report' then
   if target is null and nullif(p_payload->>'user_id','') is null then raise exception 'Report target required.'; end if;
   if target is not null and not bibi_private.can_read_content(target) then raise exception 'Content unavailable.'; end if;
   insert into public.bibi_reports(id,user_id,content_id,target_id,reason,details)
     values(p_operation,actor,target,nullif(p_payload->>'user_id','')::uuid,p_payload->>'reason',coalesce(p_payload->>'details',''));
 when 'direct' then
   if target=actor or bibi_private.blocked(actor,target) or not exists(select 1 from public.bibi_profiles where id=target and account_status='active') then raise exception 'Person unavailable.'; end if;
   pair := least(actor::text,target::text)||':'||greatest(actor::text,target::text);
   perform pg_advisory_xact_lock(hashtextextended(pair,1));
   select id into record_id from public.bibi_conversations where direct_pair=pair;
   if record_id is null then
     record_id := p_operation;
     insert into public.bibi_conversations(id,kind,owner_id,direct_pair) values(record_id,'direct',actor,pair);
     insert into public.bibi_conversation_members(conversation_id,user_id,status,joined_at) values(record_id,actor,'active',now()),(record_id,target,'active',now());
   end if;
   result_value := jsonb_build_object('id',record_id);
 when 'group' then
   record_id := p_operation;
   insert into public.bibi_conversations(id,kind,owner_id,title) values(record_id,'group',actor,trim(p_payload->>'title'));
   insert into public.bibi_conversation_members(conversation_id,user_id,status,joined_at) values(record_id,actor,'active',now());
   result_value := jsonb_build_object('id',record_id);
 when 'invite','accept_invite','leave','remove_member' then
   select * into room from public.bibi_conversations where id=target and kind='group' for update;
   if not found then raise exception 'Group unavailable.'; end if;
   peer := nullif(p_payload->>'user_id','')::uuid;
   if p_action='invite' then
     if room.owner_id is distinct from actor or not bibi_private.can_read_conversation(target) or peer=actor or bibi_private.blocked(actor,peer)
       or not exists(select 1 from public.bibi_follows where user_id=actor and target_id=peer)
       or not exists(select 1 from public.bibi_follows where user_id=peer and target_id=actor)
       or (select count(*) from public.bibi_conversation_members where conversation_id=target and status in ('active','invited'))>=50 then raise exception 'Invitation unavailable.'; end if;
     insert into public.bibi_conversation_members(conversation_id,user_id,status) values(target,peer,'invited')
       on conflict(conversation_id,user_id) do update set status='invited',joined_at=null where bibi_conversation_members.status='left';
   elsif p_action='accept_invite' then
     if bibi_private.blocked(actor,room.owner_id) then raise exception 'Invitation unavailable.'; end if;
     update public.bibi_conversation_members set status='active',joined_at=clock_timestamp(),joined_sequence=coalesce((select max(sequence) from public.bibi_messages where conversation_id=target),0) where conversation_id=target and user_id=actor and status='invited';
     if not found then raise exception 'Invitation unavailable.'; end if;
   else
     if p_action='remove_member' and (room.owner_id is distinct from actor or peer=actor or not bibi_private.can_read_conversation(target)) then raise exception 'Membership change denied.'; end if;
     update public.bibi_conversation_members set status='left' where conversation_id=target and user_id=case when p_action='leave' then actor else peer end;
   end if;
 when 'send' then
   select direct_pair into pair from public.bibi_conversations where id=target;
   if pair is not null then perform pg_advisory_xact_lock(hashtextextended(pair,1)); end if;
   select * into room from public.bibi_conversations where id=target for update;
   if not found or not bibi_private.can_read_conversation(target) then raise exception 'Conversation unavailable.'; end if;
   if room.kind='direct' then
     select user_id into peer from public.bibi_conversation_members where conversation_id=target and user_id<>actor;
     if not (exists(select 1 from public.bibi_follows where user_id=actor and target_id=peer)
       and exists(select 1 from public.bibi_follows where user_id=peer and target_id=actor))
       and exists(select 1 from public.bibi_messages where conversation_id=target and sender_id=actor)
       then raise exception 'Follow each other to send another message.'; end if;
   end if;
   insert into public.bibi_messages(id,conversation_id,sender_id,body) values(p_operation,target,actor,trim(p_payload->>'body'));
   select to_jsonb(m) into result_value from public.bibi_messages m where id=p_operation;
 when 'chat_preferences' then
   if not bibi_private.can_read_conversation(target) then raise exception 'Conversation unavailable.'; end if;
   update public.bibi_conversation_members set pinned=coalesce((p_payload->>'pinned')::boolean,pinned),
     muted=coalesce((p_payload->>'muted')::boolean,muted),hidden=coalesce((p_payload->>'hidden')::boolean,hidden),
     read_sequence=greatest(read_sequence,least(coalesce((p_payload->>'read_sequence')::bigint,read_sequence),
       coalesce((select max(sequence) from public.bibi_messages where conversation_id=target),0)))
     where conversation_id=target and user_id=actor;
 when 'gift' then
   raise exception 'Post gifts are no longer available. No diamonds were spent.';
 else raise exception 'Unsupported action.';
 end case;
 update bibi_private.operations set result=result_value where user_id=actor and id=p_operation;
 return result_value;
end $$;
create function public.bibi_command(p_operation uuid,p_action text,p_payload jsonb) returns jsonb
language sql security invoker set search_path = '' as $$ select bibi_private.command(p_operation,p_action,p_payload) $$;
create function bibi_private.finalize_media(p_user uuid,p_media uuid,p_size bigint,p_mime text,p_duration numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare item public.bibi_media;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 select * into item from public.bibi_media where id=p_media and owner_id=p_user for update;
 if not found or item.status='removed' or not exists(select 1 from public.bibi_profiles where id=p_user and account_status='active')
 or p_size is null or p_size not between 1 and 50000000 or p_mime<>item.mime_type
 or (item.bucket_id='bibi-images' and p_size>1000000)
 or (item.bucket_id='bibi-videos' and (p_duration is null or p_duration not between 0.01 and 180))
 then raise exception 'Invalid uploaded media.'; end if;
 if not exists(select 1 from storage.objects where bucket_id=item.bucket_id and name=item.object_path) then raise exception 'Upload missing.'; end if;
 update public.bibi_media set status='ready',byte_count=p_size,duration_seconds=p_duration where id=p_media;
 return jsonb_build_object('id',p_media,'status','ready');
end $$;
create function public.bibi_finalize_media(p_user uuid,p_media uuid,p_size bigint,p_mime text,p_duration numeric) returns jsonb
language sql security invoker set search_path='' as $$ select bibi_private.finalize_media(p_user,p_media,p_size,p_mime,p_duration) $$;

create function bibi_private.credit_purchase(p_user uuid,p_transaction text,p_environment text,p_product text,p_quantity integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior bibi_private.apple_transactions; amount bigint; current_balance bigint;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 if p_environment not in ('Sandbox','Production') or p_quantity is null or p_quantity not between 1 and 10
 or p_transaction is null or char_length(p_transaction) not between 1 and 100
 or not exists(select 1 from public.bibi_profiles where id=p_user and account_status='active') then raise exception 'Purchase unavailable.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_environment||':'||p_transaction,2));
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
create function public.bibi_credit_purchase(p_user uuid,p_transaction text,p_environment text,p_product text,p_quantity integer) returns jsonb
language sql security invoker set search_path='' as $$ select bibi_private.credit_purchase(p_user,p_transaction,p_environment,p_product,p_quantity) $$;

create function bibi_private.revoke_purchase(p_transaction text,p_environment text) returns void
language plpgsql security definer set search_path='' as $$
declare item bibi_private.apple_transactions; current_balance bigint;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_environment||':'||p_transaction,2));
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
create function public.bibi_revoke_purchase(p_transaction text,p_environment text) returns void
language sql security invoker set search_path='' as $$ select bibi_private.revoke_purchase(p_transaction,p_environment) $$;

create function bibi_private.begin_deletion(p_user uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 update public.bibi_profiles set account_status='deleting' where id=p_user;
 insert into bibi_private.deletion_jobs(user_id) values(p_user) on conflict do nothing;
 return jsonb_build_object('user_id',p_user,'status','deleting');
end $$;
create function public.bibi_begin_deletion(p_user uuid) returns jsonb
language sql security invoker set search_path='' as $$ select bibi_private.begin_deletion(p_user) $$;

create function bibi_private.moderate(p_content uuid,p_revision uuid,p_approve boolean) returns void
language plpgsql security definer set search_path='' as $$
declare item public.bibi_content;
begin
 select * into item from public.bibi_content where id=p_content for update;
 if not found or item.pending_revision is distinct from p_revision then raise exception 'Pending revision changed.'; end if;
 update public.bibi_content_revisions set status=case when p_approve then 'approved' else 'rejected' end where id=p_revision;
 update public.bibi_content set approved_revision=case when p_approve then p_revision else approved_revision end,
 pending_revision=null,removed=case when p_approve then false else removed end where id=p_content;
end $$;
create function public.bibi_moderate(p_content uuid,p_revision uuid,p_approve boolean) returns void
language sql security invoker set search_path='' as $$ select bibi_private.moderate(p_content,p_revision,p_approve) $$;

create function bibi_private.content_counts(p_content uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('likes',(select count(*) from public.bibi_likes where content_id=p_content),
 'saves',(select count(*) from public.bibi_saved where content_id=p_content),
 'shares',(select count(*) from public.bibi_shares where content_id=p_content),
 'comments',(select count(*) from public.bibi_content where parent_id=p_content and bibi_private.can_read_content(id)))
 where bibi_private.can_read_content(p_content)
$$;
create function public.bibi_content_counts(p_content uuid) returns jsonb
language sql security invoker set search_path='' as $$ select bibi_private.content_counts(p_content) $$;

alter table public.bibi_profiles enable row level security;
revoke all on public.bibi_profiles from anon, authenticated;
grant select on public.bibi_profiles to authenticated;
grant all on public.bibi_profiles to service_role;
create policy bibi_read on public.bibi_profiles for select to authenticated using (bibi_private.active_actor() is not null and (id=bibi_private.active_actor() or (account_status='active' and not bibi_private.blocked(bibi_private.active_actor(),id))));
alter table public.bibi_consents enable row level security;
revoke all on public.bibi_consents from anon, authenticated;
grant select on public.bibi_consents to authenticated;
grant all on public.bibi_consents to service_role;
create policy bibi_read on public.bibi_consents for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_circles enable row level security;
revoke all on public.bibi_circles from anon, authenticated;
grant select on public.bibi_circles to authenticated;
grant all on public.bibi_circles to service_role;
create policy bibi_read on public.bibi_circles for select to authenticated using (bibi_private.active_actor() is not null and active);
alter table public.bibi_challenges enable row level security;
revoke all on public.bibi_challenges from anon, authenticated;
grant select on public.bibi_challenges to authenticated;
grant all on public.bibi_challenges to service_role;
create policy bibi_read on public.bibi_challenges for select to authenticated using (bibi_private.active_actor() is not null and active);
alter table public.bibi_circle_members enable row level security;
revoke all on public.bibi_circle_members from anon, authenticated;
grant select on public.bibi_circle_members to authenticated;
grant all on public.bibi_circle_members to service_role;
create policy bibi_read on public.bibi_circle_members for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_follows enable row level security;
revoke all on public.bibi_follows from anon, authenticated;
grant select on public.bibi_follows to authenticated;
grant all on public.bibi_follows to service_role;
create policy bibi_read on public.bibi_follows for select to authenticated using (bibi_private.active_actor() is not null and (user_id=bibi_private.active_actor() or target_id=bibi_private.active_actor()));
alter table public.bibi_blocks enable row level security;
revoke all on public.bibi_blocks from anon, authenticated;
grant select on public.bibi_blocks to authenticated;
grant all on public.bibi_blocks to service_role;
create policy bibi_read on public.bibi_blocks for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_media enable row level security;
revoke all on public.bibi_media from anon, authenticated;
grant select on public.bibi_media to authenticated;
grant all on public.bibi_media to service_role;
create policy bibi_read on public.bibi_media for select to authenticated using (bibi_private.can_read_media(id));
alter table public.bibi_content enable row level security;
revoke all on public.bibi_content from anon, authenticated;
grant select on public.bibi_content to authenticated;
grant all on public.bibi_content to service_role;
create policy bibi_read on public.bibi_content for select to authenticated using (bibi_private.can_read_content(id));
alter table public.bibi_content_revisions enable row level security;
revoke all on public.bibi_content_revisions from anon, authenticated;
grant select on public.bibi_content_revisions to authenticated;
grant all on public.bibi_content_revisions to service_role;
create policy bibi_read on public.bibi_content_revisions for select to authenticated using (exists(select 1 from public.bibi_content c where c.id=content_id and bibi_private.can_read_content(c.id)
 and (c.owner_id=bibi_private.active_actor() or c.approved_revision=bibi_content_revisions.id)));
alter table public.bibi_saved enable row level security;
revoke all on public.bibi_saved from anon, authenticated;
grant select on public.bibi_saved to authenticated;
grant all on public.bibi_saved to service_role;
create policy bibi_read on public.bibi_saved for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_likes enable row level security;
revoke all on public.bibi_likes from anon, authenticated;
grant select on public.bibi_likes to authenticated;
grant all on public.bibi_likes to service_role;
create policy bibi_read on public.bibi_likes for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_shares enable row level security;
revoke all on public.bibi_shares from anon, authenticated;
grant select on public.bibi_shares to authenticated;
grant all on public.bibi_shares to service_role;
create policy bibi_read on public.bibi_shares for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_entries enable row level security;
revoke all on public.bibi_entries from anon, authenticated;
grant select on public.bibi_entries to authenticated;
grant all on public.bibi_entries to service_role;
create policy bibi_read on public.bibi_entries for select to authenticated using (user_id=bibi_private.active_actor() or bibi_private.can_read_content(video_id));
alter table public.bibi_reports enable row level security;
revoke all on public.bibi_reports from anon, authenticated;
grant select on public.bibi_reports to authenticated;
grant all on public.bibi_reports to service_role;
create policy bibi_read on public.bibi_reports for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_conversations enable row level security;
revoke all on public.bibi_conversations from anon, authenticated;
grant select on public.bibi_conversations to authenticated;
grant all on public.bibi_conversations to service_role;
create policy bibi_read on public.bibi_conversations for select to authenticated using (bibi_private.can_read_conversation(id));
alter table public.bibi_conversation_members enable row level security;
revoke all on public.bibi_conversation_members from anon, authenticated;
grant select on public.bibi_conversation_members to authenticated;
grant all on public.bibi_conversation_members to service_role;
create policy bibi_read on public.bibi_conversation_members for select to authenticated using ((user_id=bibi_private.active_actor() or bibi_private.can_read_conversation(conversation_id)));
alter table public.bibi_messages enable row level security;
revoke all on public.bibi_messages from anon, authenticated;
grant select on public.bibi_messages to authenticated;
grant all on public.bibi_messages to service_role;
create policy bibi_read on public.bibi_messages for select to authenticated using (bibi_private.can_read_conversation(conversation_id)
 and (sender_id is null or not bibi_private.blocked(bibi_private.active_actor(),sender_id))
 and exists(select 1 from public.bibi_conversation_members m where m.conversation_id=bibi_messages.conversation_id
 and m.user_id=bibi_private.active_actor() and m.status='active' and m.joined_sequence<bibi_messages.sequence));
alter table public.bibi_wallets enable row level security;
revoke all on public.bibi_wallets from anon, authenticated;
grant select on public.bibi_wallets to authenticated;
grant all on public.bibi_wallets to service_role;
create policy bibi_read on public.bibi_wallets for select to authenticated using (user_id=bibi_private.active_actor());
alter table public.bibi_wallet_activity enable row level security;
revoke all on public.bibi_wallet_activity from anon, authenticated;
grant select on public.bibi_wallet_activity to authenticated;
grant all on public.bibi_wallet_activity to service_role;
create policy bibi_read on public.bibi_wallet_activity for select to authenticated using (user_id=bibi_private.active_actor());
alter table bibi_private.operations enable row level security;
revoke all on bibi_private.operations from anon,authenticated;
alter table bibi_private.apple_transactions enable row level security;
revoke all on bibi_private.apple_transactions from anon,authenticated;
alter table bibi_private.deletion_jobs enable row level security;
revoke all on bibi_private.deletion_jobs from anon,authenticated;
alter table bibi_private.products enable row level security;
revoke all on bibi_private.products from anon,authenticated;
alter table bibi_private.gifts enable row level security;
revoke all on bibi_private.gifts from anon,authenticated;

revoke all on all functions in schema bibi_private from public, anon, authenticated;
grant execute on all functions in schema bibi_private to service_role;
grant execute on function bibi_private.active_actor(),bibi_private.blocked(uuid,uuid),
 bibi_private.can_read_content(uuid),bibi_private.can_read_conversation(uuid),bibi_private.can_read_media(uuid),
 bibi_private.enroll(text,boolean,text),bibi_private.command(uuid,text,jsonb),bibi_private.content_counts(uuid) to authenticated;
revoke all on function public.bibi_enroll(text,boolean,text),public.bibi_command(uuid,text,jsonb),public.bibi_content_counts(uuid),
 public.bibi_finalize_media(uuid,uuid,bigint,text,numeric),public.bibi_credit_purchase(uuid,text,text,text,integer),
 public.bibi_revoke_purchase(text,text),public.bibi_begin_deletion(uuid),public.bibi_moderate(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.bibi_enroll(text,boolean,text),public.bibi_command(uuid,text,jsonb),public.bibi_content_counts(uuid) to authenticated;
grant execute on function public.bibi_finalize_media(uuid,uuid,bigint,text,numeric),public.bibi_credit_purchase(uuid,text,text,text,integer),
 public.bibi_revoke_purchase(text,text),public.bibi_begin_deletion(uuid),public.bibi_moderate(uuid,uuid,boolean) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('bibi-images','bibi-images',false,1000000,array['image/jpeg','image/png']),
 ('bibi-videos','bibi-videos',false,50000000,array['video/mp4']);
create policy bibi_upload on storage.objects for insert to authenticated with check (
 bucket_id in ('bibi-images','bibi-videos') and exists(select 1 from public.bibi_media m
 where m.object_path=name and m.bucket_id=storage.objects.bucket_id and m.owner_id=bibi_private.active_actor() and m.status='uploading'));
create policy bibi_download on storage.objects for select to authenticated using (
 bucket_id in ('bibi-images','bibi-videos') and exists(select 1 from public.bibi_media m
 where m.object_path=name and m.bucket_id=storage.objects.bucket_id and bibi_private.can_read_media(m.id)));
-- Objects are immutable to clients: replacement requires a new staged asset ID.
alter publication supabase_realtime add table public.bibi_messages,public.bibi_conversation_members,public.bibi_content;
