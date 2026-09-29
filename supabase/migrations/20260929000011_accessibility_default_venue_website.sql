-- The default accessibility value is now always 'See venue website' — the
-- previous 'Wheelchair accessible' default relied on Paris Open Data's own
-- pmr flag, which the app has no way to verify, so it's no longer used to
-- make an accessibility claim. Replaces the 480 existing rows that had it.
-- sync-exhibitions/index.ts's normalizeParisEvent updated and redeployed
-- to match before this runs.

UPDATE exhibitions
SET accessibility = 'See venue website'
WHERE accessibility = 'Wheelchair accessible';
