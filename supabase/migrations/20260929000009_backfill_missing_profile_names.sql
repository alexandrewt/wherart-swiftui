-- Backfills first_name/last_name for the 6 profiles left blank by the
-- signInWithGoogle/signInWithApple bug fixed in Services/SupabaseService.swift:
-- both functions sent an `email` field in the profiles upsert payload, but
-- the `profiles` table has no `email` column — PostgREST rejected the whole
-- upsert, so first_name/last_name silently never got saved either, even
-- though the sign-in itself had already succeeded.
--
-- Recovered from auth.identities.identity_data, which Google/Apple already
-- populated at sign-in time:
--   - 2 Google accounts had full_name available -> split into first/last.
--   - 2 legacy email/password accounts (May/Aug 2026, predate this fix)
--     had first_name in their identity_data but it was never copied —
--     backfilled from there; last_name wasn't available for these two.
--   - 2 Apple accounts have no name in identity_data at all (Apple only
--     provides it on the very first authorization) — not recoverable, left
--     blank; the app already falls back to a generic greeting for that
--     case.

UPDATE profiles SET first_name = 'Jules'
WHERE id = '13921997-b9fd-4b9d-a709-e644b834821c' AND (first_name IS NULL OR first_name = '');

UPDATE profiles SET first_name = 'Aymeric'
WHERE id = '9f226a33-06b2-4992-af54-a02499af0c99' AND (first_name IS NULL OR first_name = '');

UPDATE profiles SET first_name = 'Lola', last_name = 'Bouquet'
WHERE id = '357f31db-5a02-4ac0-b33c-cb1fbad2a420' AND (first_name IS NULL OR first_name = '');

UPDATE profiles SET first_name = 'Alexandre', last_name = 'de Witt'
WHERE id = '9f77d5ec-a819-4dca-bef2-e73607b45eec' AND (first_name IS NULL OR first_name = '');
