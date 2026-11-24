# Sources

Everything in this skill comes from these pages. All were read on 2026-11-24.

## The X thread (Neon, @neondatabase, 2026-11-24)

- Root post: https://x.com/neondatabase/status/2125291626524467359
- 1. Ignoring MVCC: https://x.com/neondatabase/status/2125291628101542033
- 2. Leaving transactions open: https://x.com/neondatabase/status/2125291630148354260
- 3. Bulk DELETE instead of partitioning: https://x.com/neondatabase/status/2125291632077754487
- 4. Keeping unused indexes: https://x.com/neondatabase/status/2125291634065915908
- Credit and link to the talk: https://x.com/neondatabase/status/2125291635840086482

## The talk (Scott Mead, NYC Postgres Meetup, 2026-11-18)

- Slides: https://pgcraftsman.github.io/talks/the-postgres-mistakes-we-all-still-make/deck/public/slides-postable.html (CC BY 4.0)
- Source repo with the SQL, slide source, and where the numbers come from: https://github.com/pgcraftsman/talks/tree/main/the-postgres-mistakes-we-all-still-make (SQL under the PostgreSQL License), read at commit b75fcb5d618611d980c82e2d5561c01e761ba4cc
  - `README.md` (how the numbers were measured)
  - `deck/slides.md` (slide text and speaker notes)
  - `demos/00_bubble_up.sql` (copied as `scripts/health-check.sql`)
  - `demos/01_open_transactions.sql`, `02_bulk_delete.sql`, `03_indexes.sql`, `05_connection_storm.sql`, `06_timeouts.sql` (copied into `references/detection-queries.md`)
- Meetup event page: https://www.meetup.com/postgres-nyc/

Slides and notes: Copyright 2026 Scott Mead, CC BY 4.0. This skill adapts and credits them.
