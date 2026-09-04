-- Fixes favorite/viewed state "undoing itself" after leaving and
-- returning to a tab. Root cause: the client's upsertInteraction() never
-- passed `onConflict`, so PostgREST fell back to resolving conflicts on
-- the table's primary key — which user_interactions rows never carry in
-- the app's payload (only user_id/exhibition_id/is_favorite/is_viewed).
-- Every toggle therefore INSERTed a new row instead of updating the
-- existing one, and a later reload could pick up a stale duplicate.
--
-- Run once in the Supabase SQL Editor. Safe to re-run.

-- 1) Collapse duplicate (user_id, exhibition_id) rows into one, keeping
--    the most permissive flags across all duplicates (bool_or) so a
--    favorite or a viewed mark set on ANY duplicate isn't lost.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_interactions' AND column_name = 'updated_at'
    ) THEN
        CREATE TEMP TABLE user_interactions_merged AS
        SELECT
            user_id,
            exhibition_id,
            bool_or(is_favorite) AS is_favorite,
            bool_or(is_viewed) AS is_viewed,
            max(updated_at) AS updated_at
        FROM user_interactions
        GROUP BY user_id, exhibition_id;

        DELETE FROM user_interactions;

        INSERT INTO user_interactions (user_id, exhibition_id, is_favorite, is_viewed, updated_at)
        SELECT user_id, exhibition_id, is_favorite, is_viewed, updated_at FROM user_interactions_merged;
    ELSE
        CREATE TEMP TABLE user_interactions_merged AS
        SELECT
            user_id,
            exhibition_id,
            bool_or(is_favorite) AS is_favorite,
            bool_or(is_viewed) AS is_viewed
        FROM user_interactions
        GROUP BY user_id, exhibition_id;

        DELETE FROM user_interactions;

        INSERT INTO user_interactions (user_id, exhibition_id, is_favorite, is_viewed)
        SELECT user_id, exhibition_id, is_favorite, is_viewed FROM user_interactions_merged;
    END IF;

    DROP TABLE user_interactions_merged;
END $$;

-- 2) Enforce one row per (user, exhibition) going forward, and give
--    PostgREST's `on_conflict=user_id,exhibition_id` something to match.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'user_interactions_user_exhibition_unique'
    ) THEN
        ALTER TABLE user_interactions
            ADD CONSTRAINT user_interactions_user_exhibition_unique UNIQUE (user_id, exhibition_id);
    END IF;
END $$;
