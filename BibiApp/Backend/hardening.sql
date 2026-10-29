-- Scoped follow-up from static review and database advisors.
create index bibi_content_approved_revision_fk_idx on public.bibi_content(id,approved_revision);
create index bibi_content_pending_revision_fk_idx on public.bibi_content(id,pending_revision);
create policy bibi_no_client_access on bibi_private.operations for all to authenticated using(false) with check(false);
create policy bibi_no_client_access on bibi_private.apple_transactions for all to authenticated using(false) with check(false);
create policy bibi_no_client_access on bibi_private.deletion_jobs for all to authenticated using(false) with check(false);
create policy bibi_no_client_access on bibi_private.products for all to authenticated using(false) with check(false);
create policy bibi_no_client_access on bibi_private.gifts for all to authenticated using(false) with check(false);
insert into public.bibi_circles(id,title,subtitle,prompt,artwork) values
 ('animation','Animation Club','Frames worth talking about','Which tiny animation detail made a story feel alive to you? Share a frame, a thought, or your own short.','PostCover-RedHorns'),
 ('characters','Character Corner','Big feelings. Favorite characters.','Design a character around one unexpected strength. What would their first adventure be?','PostCover-RedBlackHair'),
 ('sketchbook','Sketchbook Society','From first sketch to original world','Show a work in progress and tell us one thing you want to try next. Credit every reference you use.','PostCover-PinkBows'),
 ('cosplay','Cosplay Studio','Bring your imagination to life','What everyday object could become a prop for an original character? Share your process, not just the result.','PostCover-BlueBow');
insert into public.bibi_challenges(id,title,category,summary,artwork,steps) values
 ('first-frame','One Frame, One Feeling','Animation','Tell a small story through color, movement and one clear emotion.','ChallengeCover-OrangeScarf','["Choose an emotion and a simple setting.","Create a short scene with your own art or licensed footage.","Add a title and explain your creative choice."]'),
 ('character-switch','Character Switch','Cosplay','Turn an everyday look into a character from your imagination.','ChallengeCover-BlueCostume','["Sketch an original character or credit your inspiration.","Film a safe transition using clothing, props or editing.","Share the transformation in a short video."]'),
 ('world-sketch','Build a Tiny World','Art','Give a sketch, model or miniature a story of its own.','ChallengeCover-GreenArmor','["Pick a place that could only exist in your world.","Record your process or a short tour of the finished piece.","Introduce the world with an English title and caption."]'),
 ('quiet-story','A Story Without Words','Animation','Make a character''s intention clear without dialogue.','ChallengeCover-WhiteFox','["Give your character one small goal.","Use a gesture, expression or visual change to tell the story.","Keep it under three minutes and credit your sources."]');
