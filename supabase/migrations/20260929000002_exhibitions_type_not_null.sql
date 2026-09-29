-- Closes the decode-crash risk flagged after 07e1b76: exhibitions.type and
-- .venue_type were nullable, while the Swift client's Exhibition.type/
-- venueType are non-optional Strings — a future NULL (manual insert, script,
-- schema change) would throw a DecodingError on every fetch and blank the
-- whole feed for every user, not just the one bad row.
--
-- Backfill first (idempotent — matches today's 0 NULL rows, kept in case
-- this is ever re-run against a different state), then enforce at the
-- schema level so it can never happen again.

BEGIN;

UPDATE exhibitions SET type = '' WHERE type IS NULL;
UPDATE exhibitions SET venue_type = '' WHERE venue_type IS NULL;

ALTER TABLE exhibitions ALTER COLUMN type SET DEFAULT '';
ALTER TABLE exhibitions ALTER COLUMN type SET NOT NULL;

ALTER TABLE exhibitions ALTER COLUMN venue_type SET DEFAULT '';
ALTER TABLE exhibitions ALTER COLUMN venue_type SET NOT NULL;

COMMIT;
