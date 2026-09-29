-- Fix: venue_type was classified with title+description checked BEFORE
-- venue+address — backwards for a value that describes the VENUE, not the
-- individual exhibition. An exhibition's own blurb ("balades urbaines...")
-- could outrank an unambiguous venue name ("Musée d'art contemporain..."),
-- so exhibitions at the exact same address ended up with different
-- venue_type values (e.g. MAC VAL: 3x 'Museum', 1x 'Public Space').
-- sync-exhibitions/index.ts's classifyExhibition() now checks venue+address
-- first for venue_type (type is unaffected: title/description first is
-- correct there, since the art medium genuinely varies per exhibition even
-- at the same venue).
--
-- Two steps:
-- 1. Re-run venue_type classification for EVERY row (not just '' ones —
--    rows already holding a value from before this fix, or from before
--    Museum/Gallery had keyword entries at all, need overwriting too).
-- 2. Explicit guarantee, not just an assumed side effect of step 1: force
--    every exhibition sharing the exact same `venue` string to the
--    majority venue_type among that group.

BEGIN;

UPDATE exhibitions
SET venue_type = COALESCE(
  (CASE
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'musee|museum' THEN 'Museum'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'galerie|galerie marchande|galerie privee' THEN 'Gallery'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'centre d''art|centre|pole' THEN 'Art Center'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'fondation|mecene' THEN 'Foundation'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'centre culturel|espace culturel|maison' THEN 'Cultural Center'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'hotel des ventes|encheres|drouot' THEN 'Auction House'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'foire|salon|fiac|art expo' THEN 'Art Fair'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'espace public|place|parc|metro|jardin' THEN 'Public Space'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'site historique|chateau|palais|patrimoine|monument' THEN 'Historic Site'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'bibliotheque|mediatheque|bpi' THEN 'Library'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'eglise|chapelle|cathedrale|abbaye|temple' THEN 'Church & Heritage'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'institut|academie|athenee|consulat' THEN 'Cultural Institute'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'atelier|studio artiste|maison d''artiste' THEN 'Artist Studio'
  END),
  (CASE
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'musee|museum' THEN 'Museum'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'galerie|galerie marchande|galerie privee' THEN 'Gallery'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'centre d''art|centre|pole' THEN 'Art Center'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'fondation|mecene' THEN 'Foundation'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'centre culturel|espace culturel|maison' THEN 'Cultural Center'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'hotel des ventes|encheres|drouot' THEN 'Auction House'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'foire|salon|fiac|art expo' THEN 'Art Fair'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'espace public|place|parc|metro|jardin' THEN 'Public Space'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'site historique|chateau|palais|patrimoine|monument' THEN 'Historic Site'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'bibliotheque|mediatheque|bpi' THEN 'Library'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'eglise|chapelle|cathedrale|abbaye|temple' THEN 'Church & Heritage'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'institut|academie|athenee|consulat' THEN 'Cultural Institute'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'atelier|studio artiste|maison d''artiste' THEN 'Artist Studio'
  END),
  ''
);

WITH venue_modes AS (
  SELECT venue, mode() WITHIN GROUP (ORDER BY venue_type) AS consistent_type
  FROM exhibitions
  WHERE venue_type != '' AND venue IS NOT NULL AND venue != ''
  GROUP BY venue
)
UPDATE exhibitions e
SET venue_type = vm.consistent_type
FROM venue_modes vm
WHERE e.venue = vm.venue AND e.venue_type IS DISTINCT FROM vm.consistent_type;

COMMIT;
