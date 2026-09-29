-- Backfill type/venue_type for exhibitions still at the generic sync
-- defaults ('Contemporary Art' / 'Museums'), using the same keyword tables
-- as supabase/functions/sync-exhibitions/index.ts's classifyExhibition().
-- Only touches rows the Edge Function hasn't already reclassified (a fresh
-- sync just ran and updated 309 of 1003 rows) — safe to re-run.
--
-- Unmatched rows get '' (empty string), not SQL NULL: exhibitions.type and
-- .venue_type are nullable columns, but the Swift client's Exhibition.type/
-- venueType are non-optional Strings — a real NULL would throw a
-- DecodingError on every fetch and blank the whole feed for every user.
-- '' is what the client now treats as "unclassified, show no tag, always
-- pass type/venue filters" (see HomeView/MapView filteredExhibitions and
-- SharedComponents.TagBadge).
--
-- "Public Spaces" intentionally excludes "rue" from its keyword list (see
-- the Edge Function's comment): ~62% of all addresses contain "rue" as
-- part of the street name, which would make it a false-positive dump.

BEGIN;

CREATE EXTENSION IF NOT EXISTS unaccent;

UPDATE exhibitions
SET type = COALESCE(
  (CASE
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'peinture|tableau|toile|peintre|huile|acrylique|tempera|figuratif|portrait|paysage|nature morte' THEN 'Painting'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'photographie|photo|photographe|cliche|negatif|tirage|polaroid' THEN 'Photography'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'sculpture|sculpteur|bronze|marbre|pierre|statue|bas-relief|relief' THEN 'Sculpture'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'dessin|crayon|encre|graphite|charbon|fusain|mine' THEN 'Drawing'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'video|film|cinema|projection|ecran|multimedia video' THEN 'Video Art'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'street art|graffiti|murale|urbain|pochoir|tag' THEN 'Street Art'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'design|mobilier|objet|produit|industriel|graphique' THEN 'Design'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'architecture|architectural|batiment|structure|urbanisme|facade|amenagement' THEN 'Architecture'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'digital|numerique|code|pixels|synthese|infographie' THEN 'Digital Art'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'illustration|illustrateur|bande dessinee|bd|comics|planches' THEN 'Illustration'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'gravure|estampe|lithographie|serigraphie|eau-forte' THEN 'Printmaking'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'abstrait|abstraction|non-figuratif|geometrique|composition' THEN 'Abstract Art'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'moderne|modernisme|art moderne|cubisme|dadaisme|surrealisme' THEN 'Modern Art'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'asiatique|chinois|japonais|indien|thai|bouddhiste|oriental' THEN 'Asian Art'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'installation|immersif|environnement|site-specific|participatif' THEN 'Installation'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'technique mixte|collage|assemblage|multimedia|hybride' THEN 'Mixed Media'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'textile|tissu|broderie|tapisserie|laine|fil' THEN 'Textile Art'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'ceramique|poterie|porcelaine|gres|email' THEN 'Ceramics'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'performance|live|action|spectacle|danse|theatre|happening' THEN 'Performance'
  END),
  (CASE
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'peinture|tableau|toile|peintre|huile|acrylique|tempera|figuratif|portrait|paysage|nature morte' THEN 'Painting'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'photographie|photo|photographe|cliche|negatif|tirage|polaroid' THEN 'Photography'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'sculpture|sculpteur|bronze|marbre|pierre|statue|bas-relief|relief' THEN 'Sculpture'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'dessin|crayon|encre|graphite|charbon|fusain|mine' THEN 'Drawing'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'video|film|cinema|projection|ecran|multimedia video' THEN 'Video Art'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'street art|graffiti|murale|urbain|pochoir|tag' THEN 'Street Art'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'design|mobilier|objet|produit|industriel|graphique' THEN 'Design'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'architecture|architectural|batiment|structure|urbanisme|facade|amenagement' THEN 'Architecture'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'digital|numerique|code|pixels|synthese|infographie' THEN 'Digital Art'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'illustration|illustrateur|bande dessinee|bd|comics|planches' THEN 'Illustration'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'gravure|estampe|lithographie|serigraphie|eau-forte' THEN 'Printmaking'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'abstrait|abstraction|non-figuratif|geometrique|composition' THEN 'Abstract Art'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'moderne|modernisme|art moderne|cubisme|dadaisme|surrealisme' THEN 'Modern Art'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'asiatique|chinois|japonais|indien|thai|bouddhiste|oriental' THEN 'Asian Art'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'installation|immersif|environnement|site-specific|participatif' THEN 'Installation'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'technique mixte|collage|assemblage|multimedia|hybride' THEN 'Mixed Media'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'textile|tissu|broderie|tapisserie|laine|fil' THEN 'Textile Art'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'ceramique|poterie|porcelaine|gres|email' THEN 'Ceramics'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'performance|live|action|spectacle|danse|theatre|happening' THEN 'Performance'
  END),
  ''
)
WHERE type = 'Contemporary Art';

UPDATE exhibitions
SET venue_type = COALESCE(
  (CASE
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'galerie|galerie marchande|galerie privee' THEN 'Galleries'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'centre d''art|centre|pole' THEN 'Art Centers'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'fondation|mecene' THEN 'Foundations'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'centre culturel|espace culturel|maison' THEN 'Cultural Centers'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'hotel des ventes|encheres|drouot' THEN 'Auction Houses'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'foire|salon|fiac|art expo' THEN 'Art Fairs'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'espace public|place|parc|metro|jardin' THEN 'Public Spaces'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'site historique|chateau|palais|patrimoine|monument' THEN 'Historic Sites'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'bibliotheque|mediatheque|bpi' THEN 'Libraries'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'eglise|chapelle|cathedrale|abbaye|temple' THEN 'Churches & Heritage'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'institut|academie|athenee|consulat' THEN 'Cultural Institutes'
    WHEN unaccent(lower(coalesce(title,'') || ' ' || coalesce(description,''))) ~ 'atelier|studio artiste|maison d''artiste' THEN 'Artist Studios'
  END),
  (CASE
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'galerie|galerie marchande|galerie privee' THEN 'Galleries'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'centre d''art|centre|pole' THEN 'Art Centers'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'fondation|mecene' THEN 'Foundations'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'centre culturel|espace culturel|maison' THEN 'Cultural Centers'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'hotel des ventes|encheres|drouot' THEN 'Auction Houses'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'foire|salon|fiac|art expo' THEN 'Art Fairs'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'espace public|place|parc|metro|jardin' THEN 'Public Spaces'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'site historique|chateau|palais|patrimoine|monument' THEN 'Historic Sites'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'bibliotheque|mediatheque|bpi' THEN 'Libraries'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'eglise|chapelle|cathedrale|abbaye|temple' THEN 'Churches & Heritage'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'institut|academie|athenee|consulat' THEN 'Cultural Institutes'
    WHEN unaccent(lower(coalesce(venue,'') || ' ' || coalesce(address,''))) ~ 'atelier|studio artiste|maison d''artiste' THEN 'Artist Studios'
  END),
  ''
)
WHERE venue_type = 'Museums';

COMMIT;
