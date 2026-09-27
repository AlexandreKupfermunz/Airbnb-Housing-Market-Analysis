# Normalization Summary

This project's schema was normalized starting from a single, denormalized
`AIRBNB_RAW_DATA` table containing listing, property, host, city, and
regulation information all mixed together.

## Problems in the unnormalized table
- Repeated values (e.g. city and host names) stored redundantly on every row.
- Update anomalies: changing one host's details required updating every row
  for that host.
- Insertion anomalies: a regulation couldn't be recorded without an
  associated listing already existing.
- Deletion anomalies: removing all of a host's listings could silently
  delete the only record that a given host existed.

## 1NF — Atomic values
Split the single flat table into separate entities (`CITY`, `HOST`,
`NEIGHBORHOOD`, etc.) so that every column holds a single, atomic value and
each real-world concept has its own table linked by keys, rather than
repeating text fields across rows.

## 2NF — Remove partial dependencies
Where a table had a composite key, we made sure every non-key column
depended on the *whole* key, not just part of it. For example, static
property attributes (`property_type`, `bedrooms`, `capacity`) were pulled
out of the time-series `LISTING_SNAPSHOT` table (keyed by
`listing_id + snapshot_date`) and moved into the `PROPERTY` table, since
they only depend on the property, not the specific snapshot date.

## 3NF — Remove transitive dependencies
We removed cases where a non-key attribute depended on another non-key
attribute rather than directly on the primary key. For example,
`city_name`/`country` were removed from `NEIGHBORHOOD` (they depend on
`city_id`, not directly on `neighborhood_id`) and kept only in the `CITY`
table, referenced via foreign key.

## Result
The final schema (implemented in [`../sql/01_schema.sql`](../sql/01_schema.sql))
has one clear "single source of truth" per entity, avoids redundant storage,
and prevents the update/insertion/deletion anomalies described above, while
still supporting the joins needed for market analysis queries.

See `erd.pdf` in this folder for the full diagram and the original
normalization walkthrough this summary is based on.