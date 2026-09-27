-- =====================================================================
-- Airbnb Housing Market Analysis Database
-- File: 02_mock_data.sql
-- Purpose: Populates the schema with realistic mock data
-- Run AFTER 01_schema.sql, on the same connection/database (airbnb_market)
-- =====================================================================
-- Note: all tables use AUTO_INCREMENT primary keys starting at 1, and
-- this script assumes it runs against a freshly created, empty schema,
-- so the numbering in the comments below matches the generated IDs.
-- =====================================================================

USE airbnb_market;

-- ---------------------------------------------------------------------
-- CITY  (1=Barcelona, 2=Berlin, 3=Lisbon)
-- ---------------------------------------------------------------------
INSERT INTO city (name, country) VALUES
('Barcelona', 'Spain'),
('Berlin',    'Germany'),
('Lisbon',    'Portugal');

-- ---------------------------------------------------------------------
-- NEIGHBORHOOD
-- Barcelona: 1 Gothic Quarter, 2 Eixample, 3 Gracia
-- Berlin:    4 Mitte, 5 Kreuzberg
-- Lisbon:    6 Alfama, 7 Baixa
-- ---------------------------------------------------------------------
INSERT INTO neighborhood (city_id, name, census_code, latitude, longitude) VALUES
(1, 'Gothic Quarter', 'BCN-001', 41.383333, 2.176944),
(1, 'Eixample',       'BCN-002', 41.392700, 2.164700),
(1, 'Gracia',         'BCN-003', 41.402700, 2.156600),
(2, 'Mitte',           'BER-001', 52.520000, 13.404900),
(2, 'Kreuzberg',       'BER-002', 52.499200, 13.403200),
(3, 'Alfama',           'LIS-001', 38.712000, -9.130000),
(3, 'Baixa',            'LIS-002', 38.710700, -9.136500);

-- ---------------------------------------------------------------------
-- REGULATION
-- 1: Barcelona short-term rental ban
-- 2: Barcelona registration requirement (city-wide)
-- 3: Berlin Zweckentfremdungsverbot (misuse of housing ban / cap)
-- 4: Lisbon Alojamento Local suspension zones
-- ---------------------------------------------------------------------
INSERT INTO regulation (city_id, regulation_type, effective_from, effective_to, annual_night_limit, registration_required, description) VALUES
(1, 'short_term_rental_ban',   '2028-06-01', NULL, NULL, TRUE,
    'City-wide phase-out of all short-term tourist rental licenses by June 2028.'),
(1, 'registration_requirement','2016-01-01', NULL, NULL, TRUE,
    'All short-term rentals must display a valid HUTB tourist license number.'),
(2, 'night_cap',               '2014-05-01', NULL, 90, TRUE,
    'Whole-home short-term rentals capped at 90 nights per calendar year without a special permit.'),
(3, 'suspension_zone',         '2020-01-01', NULL, NULL, TRUE,
    'New Alojamento Local licenses suspended in designated high-pressure zones.');

-- ---------------------------------------------------------------------
-- REGULATION_AREA (junction: which neighborhoods each regulation covers)
-- ---------------------------------------------------------------------
INSERT INTO regulation_area (regulation_id, neighborhood_id) VALUES
(1, 1), (1, 2), (1, 3),          -- Barcelona ban covers all 3 BCN neighborhoods
(2, 1), (2, 2), (2, 3),          -- Barcelona registration requirement, same coverage
(3, 4), (3, 5),                   -- Berlin night cap covers Mitte & Kreuzberg
(4, 6);                            -- Lisbon suspension zone covers Alfama only

-- ---------------------------------------------------------------------
-- HOST
-- ---------------------------------------------------------------------
INSERT INTO host (host_type, verified, registration_date, country_origin) VALUES
('individual',   TRUE,  '2018-03-15', 'Spain'),        -- 1
('individual',   TRUE,  '2019-07-22', 'France'),        -- 2
('professional', TRUE,  '2017-01-10', 'Spain'),        -- 3
('commercial',   TRUE,  '2016-05-05', 'Germany'),       -- 4
('individual',   FALSE, '2022-11-30', 'Portugal'),      -- 5
('professional', TRUE,  '2020-02-14', 'Portugal'),      -- 6
('individual',   TRUE,  '2021-09-01', 'Germany'),       -- 7
('commercial',   TRUE,  '2015-08-19', 'Spain');         -- 8

-- ---------------------------------------------------------------------
-- PROPERTY
-- ---------------------------------------------------------------------
INSERT INTO property (neighborhood_id, property_type, bedrooms, capacity, street_address, price_per_m2_purchased) VALUES
(1, 'apartment', 2, 4, 'Carrer del Bisbe 4, Barcelona',        5200.00), -- 1
(1, 'studio',    0, 2, 'Carrer de la Palla 12, Barcelona',      5400.00), -- 2
(2, 'apartment', 3, 6, 'Passeig de Gracia 88, Barcelona',       6100.00), -- 3
(2, 'loft',      1, 2, 'Carrer de Mallorca 210, Barcelona',     5800.00), -- 4
(3, 'house',     4, 8, 'Carrer de Verdi 33, Barcelona',          4700.00), -- 5
(4, 'apartment', 2, 4, 'Torstrasse 15, Berlin',                  4200.00), -- 6
(4, 'apartment', 1, 2, 'Rosenthaler Strasse 40, Berlin',        4500.00), -- 7
(5, 'loft',      2, 4, 'Oranienstrasse 22, Berlin',              3900.00), -- 8
(5, 'apartment', 3, 6, 'Bergmannstrasse 5, Berlin',              4000.00), -- 9
(6, 'house',     3, 6, 'Rua de Sao Miguel 9, Lisbon',            3200.00), -- 10
(6, 'apartment', 1, 2, 'Rua do Salvador 21, Lisbon',             3300.00), -- 11
(7, 'apartment', 2, 4, 'Rua Augusta 100, Lisbon',                3600.00); -- 12

-- ---------------------------------------------------------------------
-- HOST_PROPERTY (junction: ownership/management relationships)
-- ---------------------------------------------------------------------
INSERT INTO host_property (host_id, property_id, ownership_type, acquisition_date) VALUES
(1, 1,  'owner',   '2018-04-01'),
(1, 2,  'owner',   '2019-06-15'),
(2, 3,  'owner',   '2020-01-20'),
(3, 4,  'manager', '2017-02-11'),
(3, 5,  'manager', '2017-03-01'),
(4, 3,  'agent',   '2021-05-10'),   -- commercial agent also manages property 3
(4, 9,  'owner',   '2016-06-01'),
(5, 10, 'owner',   '2022-12-01'),
(6, 11, 'manager', '2020-03-01'),
(6, 12, 'manager', '2020-03-01'),
(7, 6,  'owner',   '2021-10-05'),
(7, 7,  'owner',   '2022-01-15'),
(8, 8,  'owner',   '2015-09-01');

-- ---------------------------------------------------------------------
-- PLATFORM
-- ---------------------------------------------------------------------
INSERT INTO platform (name, website_url) VALUES
('Airbnb',       'https://www.airbnb.com'),
('Booking.com',  'https://www.booking.com'),
('Vrbo',          'https://www.vrbo.com');

-- ---------------------------------------------------------------------
-- LISTING
-- ---------------------------------------------------------------------
INSERT INTO listing (property_id, host_id, platform_id, room_type, license_number, first_listed_date, last_listed_date, minimum_nights) VALUES
(1,  1, 1, 'entire_home',   'HUTB-000123', '2018-05-01', NULL,         2),
(2,  1, 1, 'entire_home',   'HUTB-000456', '2019-07-01', NULL,         1),
(3,  2, 1, 'entire_home',   'HUTB-000789', '2020-02-01', NULL,         3),
(4,  3, 2, 'private_room',  'HUTB-000987', '2017-03-01', NULL,         2),
(5,  3, 1, 'entire_home',   'HUTB-000654', '2017-04-01', NULL,         5),
(6,  7, 1, 'entire_home',   NULL,           '2021-11-01', NULL,        2),
(7,  7, 2, 'entire_home',   NULL,           '2022-02-01', NULL,        1),
(8,  8, 1, 'private_room',  NULL,           '2015-10-01', '2024-01-15', 1),
(9,  4, 3, 'entire_home',   NULL,           '2016-07-01', NULL,        3),
(10, 5, 1, 'entire_home',   'AL-004521',    '2023-01-05', NULL,        3),
(11, 6, 1, 'private_room',  'AL-004890',    '2020-04-01', NULL,        2),
(12, 6, 2, 'entire_home',   'AL-005120',    '2020-04-15', NULL,        2);

-- ---------------------------------------------------------------------
-- LISTING_SNAPSHOT (monthly time series: Apr, May, Jun 2024)
-- ---------------------------------------------------------------------
INSERT INTO listing_snapshot (listing_id, snapshot_date, nightly_price, available_days_next_365, active, reviews_count) VALUES
-- Listing 1
(1, '2024-04-01', 95.00, 210, TRUE, 142),
(1, '2024-05-01', 99.00, 205, TRUE, 148),
(1, '2024-06-01', 105.00, 190, TRUE, 155),
-- Listing 2
(2, '2024-04-01', 60.00, 300, TRUE, 88),
(2, '2024-05-01', 62.00, 295, TRUE, 91),
(2, '2024-06-01', 65.00, 280, TRUE, 97),
-- Listing 3
(3, '2024-04-01', 140.00, 150, TRUE, 210),
(3, '2024-05-01', 145.00, 140, TRUE, 218),
(3, '2024-06-01', 150.00, 130, TRUE, 226),
-- Listing 4
(4, '2024-04-01', 45.00, 320, TRUE, 60),
(4, '2024-05-01', 45.00, 310, TRUE, 63),
(4, '2024-06-01', 48.00, 300, TRUE, 65),
-- Listing 5
(5, '2024-04-01', 220.00, 100, TRUE, 75),
(5, '2024-05-01', 225.00, 95, TRUE, 78),
(5, '2024-06-01', 230.00, 90, TRUE, 80),
-- Listing 6
(6, '2024-04-01', 80.00, 250, TRUE, 30),
(6, '2024-05-01', 82.00, 240, TRUE, 34),
(6, '2024-06-01', 85.00, 230, TRUE, 39),
-- Listing 7
(7, '2024-04-01', 70.00, 260, TRUE, 20),
(7, '2024-05-01', 72.00, 255, TRUE, 24),
(7, '2024-06-01', 75.00, 245, TRUE, 27),
-- Listing 8 (inactive after Jan 2024)
(8, '2024-04-01', 40.00, 0, FALSE, 112),
-- Listing 9
(9, '2024-04-01', 90.00, 200, TRUE, 55),
(9, '2024-05-01', 92.00, 195, TRUE, 58),
(9, '2024-06-01', 95.00, 185, TRUE, 61),
-- Listing 10
(10, '2024-04-01', 65.00, 300, TRUE, 12),
(10, '2024-05-01', 68.00, 290, TRUE, 15),
(10, '2024-06-01', 70.00, 280, TRUE, 18),
-- Listing 11
(11, '2024-04-01', 35.00, 330, TRUE, 44),
(11, '2024-05-01', 36.00, 325, TRUE, 47),
(11, '2024-06-01', 38.00, 315, TRUE, 50),
-- Listing 12
(12, '2024-04-01', 78.00, 240, TRUE, 33),
(12, '2024-05-01', 80.00, 235, TRUE, 36),
(12, '2024-06-01', 83.00, 225, TRUE, 40);

-- ---------------------------------------------------------------------
-- HOUSING_MARKET_OBSERVATION (per neighborhood, two quarters)
-- ---------------------------------------------------------------------
INSERT INTO housing_market_observation (neighborhood_id, observation_date, avg_rent_per_m2, average_sale_price_per_m2, long_term_rental_units, relative_poverty_household, total_households) VALUES
(1, '2024-01-01', 18.50, 5300.00, 1200, 12.30, 3400),
(1, '2024-04-01', 18.90, 5400.00, 1180, 12.50, 3410),
(2, '2024-01-01', 17.20, 6000.00, 2500, 9.80,  6100),
(2, '2024-04-01', 17.60, 6150.00, 2470, 9.90,  6120),
(3, '2024-01-01', 15.80, 4600.00, 1800, 14.10, 4200),
(3, '2024-04-01', 16.10, 4700.00, 1790, 14.30, 4210),
(4, '2024-01-01', 13.40, 4100.00, 3200, 15.60, 8800),
(4, '2024-04-01', 13.70, 4200.00, 3150, 15.80, 8820),
(5, '2024-01-01', 12.90, 3800.00, 2900, 17.20, 7600),
(5, '2024-04-01', 13.10, 3900.00, 2870, 17.40, 7620),
(6, '2024-01-01', 11.50, 3100.00, 1500, 20.10, 3900),
(6, '2024-04-01', 11.90, 3200.00, 1470, 20.40, 3910),
(7, '2024-01-01', 12.10, 3500.00, 1350, 18.70, 3600),
(7, '2024-04-01', 12.40, 3600.00, 1320, 18.90, 3610);