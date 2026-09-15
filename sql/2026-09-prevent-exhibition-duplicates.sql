-- Prevents re-introducing the 20 duplicate exhibitions removed on 2026-09-15
-- (same title imported multiple times as venue text drifted slightly between
-- Paris Open Data snapshots, e.g. "Galerie Joseph" vs "Galerie Saint Joseph",
-- or an invisible non-breaking space swapped for a regular space).
--
-- Root cause fix (whitespace normalization before upsert) lives in
-- supabase/functions/sync-exhibitions/index.ts. This script only documents
-- and (re-)creates the unique index that function's
-- upsert(..., { onConflict: 'title,venue' }) depends on to update existing
-- rows instead of inserting new ones.
--
-- Run once in the Supabase SQL Editor. Safe to re-run.

-- 1) Backfill: collapse whitespace drift (including non-breaking / narrow
--    no-break spaces) in already-stored title/venue so they match what the
--    normalized sync function will send going forward.
UPDATE exhibitions
SET title = regexp_replace(trim(title), '\s+', ' ', 'g')
WHERE title <> regexp_replace(trim(title), '\s+', ' ', 'g');

UPDATE exhibitions
SET venue = regexp_replace(trim(venue), '\s+', ' ', 'g')
WHERE venue <> regexp_replace(trim(venue), '\s+', ' ', 'g');

-- 2) Enforce one row per (title, venue) going forward, and give
--    PostgREST's `on_conflict=title,venue` something to match.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE indexname = 'exhibitions_title_venue_unique'
    ) THEN
        CREATE UNIQUE INDEX exhibitions_title_venue_unique ON exhibitions (title, venue);
    END IF;
END $$;

-- 3) Verify: should return 0 rows.
SELECT title, venue, COUNT(*)
FROM exhibitions
GROUP BY title, venue
HAVING COUNT(*) > 1;
