-- Default exhibition duration changed from '1h30' to '1h' (sync-exhibitions
-- never derives this from real data, it's a fixed constant applied to every
-- synced row) — backfills existing rows to match.

UPDATE exhibitions SET duration = '1h' WHERE duration = '1h30';
