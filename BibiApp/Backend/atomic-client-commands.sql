create or replace function bibi_private.command(p_operation uuid,p_action text,p_payload jsonb) returns jsonb
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
   if kind='video' and nullif(p_payload->>'challenge_id','') is not null then
     if not exists(select 1 from public.bibi_challenges where id=p_payload->>'challenge_id' and active) then raise exception 'Challenge unavailable.'; end if;
     insert into public.bibi_entries(id,user_id,challenge_id,video_id) values(p_operation,actor,p_payload->>'challenge_id',record_id)
       on conflict(user_id,challenge_id) do update set video_id=excluded.video_id,created_at=now();
   end if;
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
 when 'unhide_report' then
   update public.bibi_reports set hidden=false where user_id=actor and
     ((target is not null and content_id=target) or
      (target is null and content_id is null and target_id=nullif(p_payload->>'user_id','')::uuid));
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
   if jsonb_typeof(coalesce(p_payload->'members','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_payload->'members','[]'::jsonb))>49 then raise exception 'Choose up to 49 members.'; end if;
   for peer in select distinct value::uuid from jsonb_array_elements_text(coalesce(p_payload->'members','[]'::jsonb)) loop
     if peer=actor or bibi_private.blocked(actor,peer)
       or not exists(select 1 from public.bibi_follows where user_id=actor and target_id=peer)
       or not exists(select 1 from public.bibi_follows where user_id=peer and target_id=actor)
       or not exists(select 1 from public.bibi_profiles where id=peer and account_status='active') then raise exception 'Invite mutual followers only.'; end if;
     insert into public.bibi_conversation_members(conversation_id,user_id,status) values(record_id,peer,'invited');
   end loop;
   result_value := jsonb_build_object('id',record_id);
 when 'invite' ,'accept_invite','leave','remove_member' then
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
     if room.owner_id is null or bibi_private.blocked(actor,room.owner_id) or not exists(select 1 from public.bibi_profiles where id=room.owner_id and account_status='active') then raise exception 'Invitation unavailable.'; end if;
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

