-- Fix: "Musée"/"Galerie" venues (e.g. "Musée de la Chasse") were left
-- unclassified because venue_type's keyword table had no entries for them
-- at all (only Gallery-adjacent "galerie" existed; nothing for musée/
-- museum). Also singularizes venue_type's canonical English values —
-- 'Museums'/'Galleries'/etc. were the only plural category names in the
-- whole taxonomy; every type value ('Painting', not 'Paintings') and the
-- other venue values were already singular. sync-exhibitions/index.ts's
-- VENUE_KEYWORDS was updated and redeployed to match before this runs.
--
-- Three steps, in order:
-- 1. Rename existing exhibitions.venue_type values plural -> singular.
-- 2. Rename the same values inside profiles.venue_types arrays (76 profiles
--    have one of these as a saved preference — renaming only the DB/
--    classifier side would silently break their personalization the
--    moment exhibitions stop using the old plural value).
-- 3. Reclassify rows currently at venue_type='' using the full venue
--    table now that Museum/Gallery are real keyword entries.

BEGIN;

UPDATE exhibitions
SET venue_type = CASE venue_type
    WHEN 'Museums' THEN 'Museum'
    WHEN 'Galleries' THEN 'Gallery'
    WHEN 'Art Centers' THEN 'Art Center'
    WHEN 'Foundations' THEN 'Foundation'
    WHEN 'Cultural Centers' THEN 'Cultural Center'
    WHEN 'Auction Houses' THEN 'Auction House'
    WHEN 'Art Fairs' THEN 'Art Fair'
    WHEN 'Public Spaces' THEN 'Public Space'
    WHEN 'Historic Sites' THEN 'Historic Site'
    WHEN 'Libraries' THEN 'Library'
    WHEN 'Churches & Heritage' THEN 'Church & Heritage'
    WHEN 'Cultural Institutes' THEN 'Cultural Institute'
    WHEN 'Artist Studios' THEN 'Artist Studio'
  ELSE venue_type
END
WHERE venue_type IN (
  'Museums','Galleries','Art Centers','Foundations','Cultural Centers',
  'Auction Houses','Art Fairs','Public Spaces','Historic Sites','Libraries',
  'Churches & Heritage','Cultural Institutes','Artist Studios'
);

UPDATE profiles
SET venue_types = (
  SELECT array_agg(
    CASE elem
      WHEN 'Museums' THEN 'Museum'
      WHEN 'Galleries' THEN 'Gallery'
      WHEN 'Art Centers' THEN 'Art Center'
      WHEN 'Foundations' THEN 'Foundation'
      WHEN 'Cultural Centers' THEN 'Cultural Center'
      WHEN 'Auction Houses' THEN 'Auction House'
      WHEN 'Art Fairs' THEN 'Art Fair'
      WHEN 'Public Spaces' THEN 'Public Space'
      WHEN 'Historic Sites' THEN 'Historic Site'
      WHEN 'Libraries' THEN 'Library'
      WHEN 'Churches & Heritage' THEN 'Church & Heritage'
      WHEN 'Cultural Institutes' THEN 'Cultural Institute'
      WHEN 'Artist Studios' THEN 'Artist Studio'
      ELSE elem
    END
  )
  FROM unnest(venue_types) AS elem
)
WHERE venue_types && ARRAY[
  'Museums','Galleries','Art Centers','Foundations','Cultural Centers',
  'Auction Houses','Art Fairs','Public Spaces','Historic Sites','Libraries',
  'Churches & Heritage','Cultural Institutes','Artist Studios'
];

UPDATE exhibitions
SET venue_type = COALESCE(
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
  ''
)
WHERE venue_type = '';

COMMIT;
