-- Migration: Update notifications table to support multiple exhibitions
-- This changes from a single exhibition_id to an array of exhibition_ids

BEGIN;

-- Add the new exhibition_ids column if it doesn't exist
ALTER TABLE notifications
ADD COLUMN IF NOT EXISTS exhibition_ids INTEGER[] DEFAULT ARRAY[]::INTEGER[];

-- Migrate existing data from exhibition_id to exhibition_ids (if the old column exists)
-- This handles both NULL and non-NULL cases
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'exhibition_id'
  ) THEN
    UPDATE notifications
    SET exhibition_ids = CASE
      WHEN exhibition_id IS NOT NULL THEN ARRAY[exhibition_id]
      ELSE ARRAY[]::INTEGER[]
    END
    WHERE exhibition_ids = ARRAY[]::INTEGER[];

    -- Drop the old column after migration
    ALTER TABLE notifications DROP COLUMN exhibition_id;
  END IF;
END $$;

-- Create index on exhibition_ids for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_exhibition_ids
ON notifications USING GIN (exhibition_ids);

COMMIT;
