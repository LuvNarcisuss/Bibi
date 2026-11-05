-- Retain the legacy compatibility column without obsolete local resource references.
update public.bibi_circles set artwork='' where id='animation' and artwork_media_id='fdf189a6-f283-5809-88a1-517d97844f56'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
update public.bibi_circles set artwork='' where id='characters' and artwork_media_id='168ab8c1-2fc3-5196-a4f6-150e448a2ecd'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
update public.bibi_circles set artwork='' where id='sketchbook' and artwork_media_id='8a39493e-39af-5acb-a489-fe6476c3c2c2'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
update public.bibi_circles set artwork='' where id='cosplay' and artwork_media_id='f10fb566-7f9e-5200-b214-1f8a46522398'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
update public.bibi_challenges set artwork='' where id='first-frame' and artwork_media_id='390dccba-e7c7-587a-a814-912cae684278'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
update public.bibi_challenges set artwork='' where id='character-switch' and artwork_media_id='6b328e65-096f-5bc0-b9b2-116618859939'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
update public.bibi_challenges set artwork='' where id='world-sketch' and artwork_media_id='aab4e43f-9b6d-582a-937d-8e7fd8f0d5a5'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
update public.bibi_challenges set artwork='' where id='quiet-story' and artwork_media_id='611b1e92-82e0-5258-9d43-f0e33f2698b8'::uuid and artwork in ('BibiRoom2','BibiRoom4','BibiRoom6','BibiRoom8');
