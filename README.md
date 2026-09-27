# Airbnb Housing Market Analysis — Database Project

**Course:** Databases KEN2110 — Data Modelling
**Team:** Manos Chaloftidis, Matteo Restivo, Alexandre Kupfermunz

## 1. Project overview

This repository implements the relational database for our Airbnb housing
market analysis project. It models short-term rental listings, the hosts and
properties behind them, the platforms they're published on, and the local
housing-market context (rents, sale prices, and regulations) they operate in.

The design started from an ERD (see `docs/erd.pdf`) and was normalized
through 1NF → 2NF → 3NF (see `docs/normalization.md`) before being implemented
as a MySQL schema.

## 2. Repository structure

```
.
├── README.md                     <- you are here
├── docs/
│   ├── erd.pdf                   <- original ERD + normalization walkthrough
│   └── normalization.md           <- written summary of the 1NF/2NF/3NF process
└── sql/
    ├── 01_schema.sql              <- DDL: tables, keys, constraints, indexes
    ├── 02_mock_data.sql           <- realistic sample data (INSERTs)
    ├── 03_crud_operations.sql     <- example Create / Read / Update / Delete statements
    └── 04_advanced_queries.sql    <- 5 advanced analytical queries
```

## 3. Entity overview

| Table | Description |
|---|---|
| `city` | A city in the dataset (e.g. Barcelona, Berlin, Lisbon) |
| `neighborhood` | A neighborhood within a city |
| `regulation` | A short-term-rental regulation adopted by a city |
| `regulation_area` | Junction table: which neighborhoods a regulation covers (M:N) |
| `host` | A person/company that hosts short-term rentals |
| `property` | A physical unit located in a neighborhood |
| `host_property` | Junction table: which hosts own/manage which properties (M:N) |
| `platform` | A booking platform (Airbnb, Booking.com, Vrbo) |
| `listing` | A property marketed by a host on a platform |
| `listing_snapshot` | Time-series price/availability data for a listing |
| `housing_market_observation` | Time-series macro housing stats per neighborhood |

Full column definitions, data types, and constraints are in
[`sql/01_schema.sql`](sql/01_schema.sql).

## 4. How to run this project

**Requirements:** MySQL 8.0+ (Community Server, MySQL Workbench, or any
MySQL-compatible client such as DBeaver).

1. Clone the repository:
   ```bash
   git clone <this-repo-url>
   cd <repo-folder>
   ```
2. Run the scripts **in order** against your MySQL server:
   ```bash
   mysql -u <your_user> -p < sql/01_schema.sql
   mysql -u <your_user> -p < sql/02_mock_data.sql
   mysql -u <your_user> -p < sql/03_crud_operations.sql
   mysql -u <your_user> -p < sql/04_advanced_queries.sql
   ```
   Or open each file in MySQL Workbench and execute it top to bottom.

   `01_schema.sql` creates its own database (`airbnb_market`), so no manual
   `CREATE DATABASE` step is needed first.

3. To just inspect results without re-running everything, connect to the
   `airbnb_market` schema and run individual `SELECT` statements from
   `04_advanced_queries.sql`.

We did not include a full database dump for this assignment, as instructed —
the scripts above are sufficient to fully reproduce the database from
scratch.

## 5. What each SQL file demonstrates

- **`01_schema.sql`** — full DDL: primary keys, foreign keys (with
  `ON UPDATE`/`ON DELETE` rules), `UNIQUE`, `NOT NULL`, `CHECK` constraints,
  `ENUM` types for controlled vocabularies, and indexes to support the joins
  used later.
- **`02_mock_data.sql`** — realistic mock data across 3 cities, 7
  neighborhoods, 4 regulations, 8 hosts, 12 properties, 3 platforms, 12
  listings, and monthly price/availability snapshots.
- **`03_crud_operations.sql`** — annotated examples of `INSERT`, `SELECT`
  (including joins and correlated subqueries), `UPDATE`, and `DELETE`,
  including a demonstration of cascading vs. restricted deletes.
- **`04_advanced_queries.sql`** — 5 advanced queries:
  1. Average/min/max nightly price and active-listing count per
     neighborhood (joins + aggregation on the latest snapshot per listing).
  2. Hosts with more than one property, and how many listings they run
     (subquery/derived aggregation + `HAVING`).
  3. Ranking listings by price within their own neighborhood
     (`RANK() OVER (PARTITION BY ...)`).
  4. Month-over-month listing price growth vs. neighborhood rent growth
     (CTEs + `LAG()` window function across two fact tables).
  5. Listings potentially violating a regulation's annual night limit,
     grouped by neighborhood and regulation (M:N join + correlated
     subquery + conditional aggregation).

## 6. Team workflow / collaboration

- All team members have **write access** to this repository.
- We work on feature branches (e.g. `schema-update`, `add-queries`) and open
  **Pull Requests** into `main` for review — no direct pushes to `main`.
- Each PR requires at least one approval from another team member before
  merging, so we all read and understand every change to the schema and
  queries.
- Commit messages describe *what* changed and *why* (e.g. "Add CHECK
  constraint to prevent negative nightly prices").

## 7. Status

- [x] GitHub repository set up
- [x] ERD converted to relational schema
- [x] Schema implemented with constraints and data types
- [x] CRUD scripts written
- [x] Mock data populated
- [x] 5 advanced queries added
- [ ] TA feedback pending