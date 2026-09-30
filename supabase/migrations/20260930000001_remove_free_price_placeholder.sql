-- sync-exhibitions used to store the literal English word 'Free' in the
-- price column whenever Paris Open Data had no real price_detail text but
-- flagged the exhibition as free — 500 of 1006 rows. That placeholder
-- didn't match any of parsedPriceDisplay's French free-wording patterns
-- (SharedComponents.swift), so it was misread as leftover conditions text:
-- cards wrongly showed "Gratuit sous conditions", and tapping through
-- leaked the untranslated word "Free" into the pricing sheet instead of a
-- real API explanation. sync-exhibitions/index.ts updated and redeployed
-- to stop writing this placeholder (empty string instead) before this runs.

UPDATE exhibitions
SET price = ''
WHERE price = 'Free';
