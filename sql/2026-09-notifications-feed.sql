-- ⚠️ OBSOLÈTE — remplacé par supabase/migrations/20260915000001_update_notifications_to_multiple_exhibitions.sql
-- Ne pas rejouer sur une base existante. Gardé pour historique.
-- Créait une colonne `exhibition_id` (unique) remplacée par `exhibition_ids` (array).

-- In-app notifications feed + unread badge system.
--
-- Run once in the Supabase SQL Editor. Idempotent (IF NOT EXISTS / CREATE
-- POLICY guarded) so it's safe to re-run.

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exhibition_id INTEGER REFERENCES exhibitions(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOLEAN NOT NULL DEFAULT FALSE
);

-- In case the table already existed without it.
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- SELECT: a user reads their own notification feed.
DROP POLICY IF EXISTS "users_see_own_notifications" ON notifications;
CREATE POLICY "users_see_own_notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT: the client writes its own feed row right after scheduling a
-- local notification (EndingSoonService/NewExhibitionsService), with the
-- anon key as the signed-in user — without this, that insert fails with a
-- row-level-security violation and the feed/badge stay empty forever.
DROP POLICY IF EXISTS "users_insert_own_notifications" ON notifications;
CREATE POLICY "users_insert_own_notifications" ON notifications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATE: marking a notification (or all of them) as read.
DROP POLICY IF EXISTS "users_update_own_notifications" ON notifications;
CREATE POLICY "users_update_own_notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- DELETE: swiping a notification away in NotificationsView.
DROP POLICY IF EXISTS "users_delete_own_notifications" ON notifications;
CREATE POLICY "users_delete_own_notifications" ON notifications
  FOR DELETE USING (auth.uid() = user_id);
