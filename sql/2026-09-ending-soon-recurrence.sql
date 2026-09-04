-- Ending Soon recurrence (once/daily/weekly) + "New exhibitions matching
-- your taste" daily digest notification.
--
-- Run once in the Supabase SQL Editor. Idempotent (IF NOT EXISTS / CREATE
-- POLICY guarded) so it's safe to re-run.

-- Récurrence Ending Soon
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ending_soon_frequency TEXT DEFAULT 'once';
-- Values: 'once' | 'daily' | 'weekly'

-- Tracker: last time an Ending Soon reminder was sent for a given
-- (user, exhibition) at a given frequency. One row per frequency the user
-- was on when last notified — switching frequency in settings just starts
-- a fresh row rather than needing to migrate/delete the old one.
CREATE TABLE IF NOT EXISTS ending_soon_notifications_sent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exhibition_id INTEGER NOT NULL REFERENCES exhibitions(id) ON DELETE CASCADE,
    frequency TEXT NOT NULL,
    last_sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, exhibition_id, frequency)
);

CREATE INDEX IF NOT EXISTS idx_ending_soon_notifications_user_id ON ending_soon_notifications_sent(user_id);

-- Tracker: last time the "New exhibitions matching your taste" digest was
-- sent to a user (capped at once per day).
CREATE TABLE IF NOT EXISTS new_exhibitions_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    last_notification_sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

ALTER TABLE ending_soon_notifications_sent ENABLE ROW LEVEL SECURITY;
ALTER TABLE new_exhibitions_notifications ENABLE ROW LEVEL SECURITY;

-- SELECT: a user can read their own tracker rows (used by the client to
-- decide whether it's time to send again).
DROP POLICY IF EXISTS "users_see_own_ending_soon_notifications" ON ending_soon_notifications_sent;
CREATE POLICY "users_see_own_ending_soon_notifications" ON ending_soon_notifications_sent
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_see_own_new_exhibitions_notifications" ON new_exhibitions_notifications;
CREATE POLICY "users_see_own_new_exhibitions_notifications" ON new_exhibitions_notifications
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT/UPDATE: the client upserts these rows directly (with the anon
-- key, as the signed-in user) right after sending a local notification —
-- without these, EndingSoonService/NewExhibitionsService's upserts would
-- fail with a row-level-security violation.
DROP POLICY IF EXISTS "users_insert_own_ending_soon_notifications" ON ending_soon_notifications_sent;
CREATE POLICY "users_insert_own_ending_soon_notifications" ON ending_soon_notifications_sent
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_update_own_ending_soon_notifications" ON ending_soon_notifications_sent;
CREATE POLICY "users_update_own_ending_soon_notifications" ON ending_soon_notifications_sent
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_insert_own_new_exhibitions_notifications" ON new_exhibitions_notifications;
CREATE POLICY "users_insert_own_new_exhibitions_notifications" ON new_exhibitions_notifications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_update_own_new_exhibitions_notifications" ON new_exhibitions_notifications;
CREATE POLICY "users_update_own_new_exhibitions_notifications" ON new_exhibitions_notifications
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
