-- Remote, key-value config the app reads at launch — no app release needed
-- to change these. First use case: forcing an update by setting
-- minimum_required_version. Publicly readable (the check must work for
-- signed-out/guest users too, before any auth happens); writable only via
-- the Supabase dashboard/SQL editor (service role), never from the app —
-- no client-facing insert/update/delete policy is defined.

CREATE TABLE IF NOT EXISTS app_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_config_public_read" ON app_config
  FOR SELECT
  USING (true);

-- Requires 1.6.4 for this release only, per the user's own instruction —
-- not meant to auto-escalate with every future version. Leave this row
-- alone (or delete it / set it to '0') whenever a future release should
-- NOT be force-required.
INSERT INTO app_config (key, value)
VALUES ('minimum_required_version', '1.6.4')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
