-- Removes exhibitions that are duplicates of another row: same title, same
-- physical venue (identical GPS coordinates), Paris Open Data just spelled
-- the venue name differently across records (e.g. "Centre Paris Anim'
-- Wangari Maathai" vs. "... Wangari Muta Maathai", "Bibliothèque
-- historique de la Ville de Paris" vs. "... (BHVP)").
-- sync-exhibitions/index.ts's same-batch dedup was fixed to match by
-- title+coordinates instead of title+venue text so this doesn't recur
-- within a single sync run (a cross-run recurrence — a future sync
-- spelling an existing venue differently again — is still possible; the
-- upsert's onConflict key is (title, venue), an exact string match).
--
-- Applied manually via the Supabase SQL Editor before this file existed —
-- recorded here for migration history; re-running is a no-op (rows are
-- already gone).
--
-- Kept id 35300 over its pair 39925 despite 39925's venue name being the
-- more complete one ("Wangari Muta Maathai") — 35300 carries a real user
-- favorite (is_favorite=true), never dropped for a cosmetic preference.
-- id 23 was referenced by one notification's exhibition_ids array (test
-- data) — remapped to its pair 39989 before deleting 23. ids 22 and 42 had
-- no references; kept their pairs (39927, 40092).

BEGIN;

UPDATE notifications
SET exhibition_ids = array_replace(exhibition_ids, 23, 39989)
WHERE 23 = ANY(exhibition_ids);

DELETE FROM exhibitions WHERE id IN (22, 23, 42, 39925);

COMMIT;
