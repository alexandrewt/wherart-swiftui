-- Duration now derives from venue_type instead of a flat constant —
-- matches sync-exhibitions/index.ts's durationForVenueType(), applied here
-- to the 1003 existing rows.
--
-- Gallery / unclassified ('') / Public Space / Artist Studio /
--   Church & Heritage -> 30min
-- Museum / Art Center / Foundation / Cultural Center / Art Fair -> 1h30
-- Everything else (Auction House / Historic Site / Library /
--   Cultural Institute) -> 1h

UPDATE exhibitions
SET duration = CASE
  WHEN venue_type IN ('Gallery', '', 'Public Space', 'Artist Studio', 'Church & Heritage') THEN '30min'
  WHEN venue_type IN ('Museum', 'Art Center', 'Foundation', 'Cultural Center', 'Art Fair') THEN '1h30'
  ELSE '1h'
END;
