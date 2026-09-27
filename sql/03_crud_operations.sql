-- =====================================================================
-- Airbnb Housing Market Analysis Database
-- File: 03_crud_operations.sql
-- Purpose: Demonstrates basic CREATE / READ / UPDATE / DELETE operations
--          against the schema. Run after 01_schema.sql and 02_mock_data.sql.
-- =====================================================================
-- Each block is self-contained and commented. Run them individually
-- (one statement / block at a time) to see each operation's effect,
-- or run the whole file top to bottom.
-- =====================================================================

USE airbnb_market;

-- =====================================================================
-- 1. CREATE — inserting new records
-- =====================================================================

-- 1a. Add a brand-new host
INSERT INTO host (host_type, verified, registration_date, country_origin)
VALUES ('individual', FALSE, CURDATE(), 'Italy');

-- 1b. Add a new property for that host's city (assumes neighborhood_id 2 = Eixample)
INSERT INTO property (neighborhood_id, property_type, bedrooms, capacity, street_address, price_per_m2_purchased)
VALUES (2, 'apartment', 2, 4, 'Carrer de Valencia 300, Barcelona', 6200.00);

-- 1c. Link the new host to the new property via HOST_PROPERTY
INSERT INTO host_property (host_id, property_id, ownership_type, acquisition_date)
VALUES (
    (SELECT host_id FROM host ORDER BY host_id DESC LIMIT 1),
    (SELECT property_id FROM property ORDER BY property_id DESC LIMIT 1),
    'owner',
    CURDATE()
);

-- 1d. Create a listing for that property on Airbnb (platform_id 1)
INSERT INTO listing (property_id, host_id, platform_id, room_type, license_number, first_listed_date, minimum_nights)
VALUES (
    (SELECT property_id FROM property ORDER BY property_id DESC LIMIT 1),
    (SELECT host_id FROM host ORDER BY host_id DESC LIMIT 1),
    1,
    'entire_home',
    'HUTB-999999',
    CURDATE(),
    2
);

-- 1e. Log the first price snapshot for that listing
INSERT INTO listing_snapshot (listing_id, snapshot_date, nightly_price, available_days_next_365, active, reviews_count)
VALUES (
    (SELECT listing_id FROM listing ORDER BY listing_id DESC LIMIT 1),
    CURDATE(),
    110.00,
    365,
    TRUE,
    0
);

-- =====================================================================
-- 2. READ — basic SELECT queries
-- =====================================================================

-- 2a. All listings currently active, with their property and host info
SELECT
    l.listing_id,
    p.street_address,
    n.name AS neighborhood,
    h.host_type,
    pl.name AS platform,
    l.room_type,
    l.minimum_nights
FROM listing l
JOIN property p       ON p.property_id = l.property_id
JOIN neighborhood n    ON n.neighborhood_id = p.neighborhood_id
JOIN host h            ON h.host_id = l.host_id
JOIN platform pl       ON pl.platform_id = l.platform_id
ORDER BY l.listing_id;

-- 2b. Most recent price snapshot per listing
SELECT ls.listing_id, ls.snapshot_date, ls.nightly_price, ls.active
FROM listing_snapshot ls
WHERE ls.snapshot_date = (
    SELECT MAX(ls2.snapshot_date)
    FROM listing_snapshot ls2
    WHERE ls2.listing_id = ls.listing_id
)
ORDER BY ls.listing_id;

-- 2c. Look up a single property by its address (parameterised in an app: WHERE street_address = ?)
SELECT * FROM property WHERE street_address LIKE '%Passeig de Gracia%';

-- =====================================================================
-- 3. UPDATE — modifying existing records
-- =====================================================================

-- 3a. A host gets verified after Anthropic-style KYC checks pass
UPDATE host
SET verified = TRUE
WHERE host_id = 5;

-- 3b. Raise the nightly price of a specific, currently-active listing snapshot
--     (in practice you'd usually INSERT a new snapshot row rather than
--      edit history — this demonstrates UPDATE on the latest row directly)
UPDATE listing_snapshot
SET nightly_price = nightly_price * 1.05
WHERE listing_id = 3
  AND snapshot_date = '2024-06-01';

-- 3c. Correct a property's bedroom count after a data-entry error
UPDATE property
SET bedrooms = 2
WHERE property_id = 4;

-- 3d. Extend a regulation's end date
UPDATE regulation
SET effective_to = '2030-12-31'
WHERE regulation_id = 3;

-- =====================================================================
-- 4. DELETE — removing records
-- =====================================================================

-- 4a. Remove a single outdated price snapshot
DELETE FROM listing_snapshot
WHERE listing_id = 8
  AND snapshot_date = '2024-04-01'
  AND active = FALSE;

-- 4b. A host relationship ends: remove the HOST_PROPERTY link
--     (the property and host records themselves are kept)
DELETE FROM host_property
WHERE host_id = 4 AND property_id = 3;

-- 4c. Cascading delete example: deleting a listing also removes its
--     snapshots automatically (ON DELETE CASCADE was set on listing_snapshot).
--     Uncomment to try it:
-- DELETE FROM listing WHERE listing_id = 12;

-- 4d. Deleting a neighborhood is blocked (ON DELETE RESTRICT) while it still
--     has properties — this is intentional, to protect referential integrity.
--     Uncomment to see the error:
-- DELETE FROM neighborhood WHERE neighborhood_id = 1;