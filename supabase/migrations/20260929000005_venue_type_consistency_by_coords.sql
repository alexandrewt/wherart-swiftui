-- The venue-name-based consistency pass (20260929000004) missed cases where
-- Paris Open Data spells the same physical venue differently across records
-- (e.g. "Mac Val" vs. "MAC VAL - Musée d'art contemporain du Val-de-Marne"),
-- which grouping by exact `venue` string treats as two different venues.
-- Coordinates for the same address are identical (mod floating-point
-- geocoding noise), so group by rounded lat/lng (~11m) instead — location
-- is what actually defines "same venue", not how a feed spells its name.

BEGIN;

WITH location_modes AS (
  SELECT
    round(lat::numeric, 4) AS lat_r,
    round(lng::numeric, 4) AS lng_r,
    mode() WITHIN GROUP (ORDER BY venue_type) AS consistent_type
  FROM exhibitions
  WHERE venue_type != '' AND lat IS NOT NULL AND lng IS NOT NULL
  GROUP BY round(lat::numeric, 4), round(lng::numeric, 4)
)
UPDATE exhibitions e
SET venue_type = lm.consistent_type
FROM location_modes lm
WHERE round(e.lat::numeric, 4) = lm.lat_r
  AND round(e.lng::numeric, 4) = lm.lng_r
  AND e.venue_type IS DISTINCT FROM lm.consistent_type;

COMMIT;
