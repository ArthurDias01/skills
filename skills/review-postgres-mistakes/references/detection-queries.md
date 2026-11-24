# Detection queries

The SQL files from Scott Mead's talk, copied unchanged from
https://github.com/pgcraftsman/talks/tree/main/the-postgres-mistakes-we-all-still-make/demos
(commit b75fcb5d618611d980c82e2d5561c01e761ba4cc). The comments in each file explain every query.

Everything is read-only except the fixes, which are commented out. Do not run a fix without the user's OK.
Most queries need the `pg_monitor` role. Some columns need a newer Postgres; the comments say which.

The SQL is under the PostgreSQL License. Copyright 2026 Scott Mead <scott@meads.us>. The full license text is in `scripts/health-check.sql`.

## Read these comments with care

The comments are the author's. A few say more than the query proves:
- "Exact duplicates" groups by columns, operator classes, expression, and predicate. It does not compare uniqueness, collation, or sort options. Compare the full definitions before you drop either index.
- The invalid index query also lists indexes that are not ready (`NOT indisready`).
- Many `application_name` values can mean there is no pooler, but apps can run their own pools, PgBouncer, or both. Check before you conclude.
- `VACUUM (VERBOSE)` does real maintenance work as well as printing details. Treat it as a change and ask first.

## Contents

- [Mistake 1 and 3: dead tuples and bloat](#bulk-delete-and-dead-tuples) (02_bulk_delete.sql)
- [Mistake 2: open transactions and the horizon](#open-transactions-and-the-horizon) (01_open_transactions.sql)
- [Mistake 4: unused indexes and HOT](#unused-indexes-and-hot) (03_indexes.sql)
- [Connections](#connections) (05_connection_storm.sql)
- [Timeouts](#timeouts) (06_timeouts.sql)

## Bulk DELETE and dead tuples

```sql
-- 02_bulk_delete.sql
-- Mistake: we still bulk DELETE instead of partitioning.
--
-- The nightly job:
--
--   DELETE FROM events WHERE created_at < now() - interval '90 days';
--
-- On a 2 billion row table that is one transaction (see 01_open_transactions.sql),
-- one dead tuple per row and one heap WAL record per row, replayed on every
-- replica. The indexes are not touched by the DELETE; vacuum pays for them
-- afterwards, scanning every index in full to remove the dead entries, and
-- the pages it empties are reused, not returned.

-- 1. After the fact: which statement wrote last night's WAL spike?
--    (pg_stat_statements; wal_bytes needs PG 13+)
SELECT left(query, 60) AS query, calls, rows,
       pg_size_pretty(wal_bytes::bigint) AS wal,
       round(total_exec_time::numeric / 1000) AS seconds
FROM pg_stat_statements
ORDER BY wal_bytes DESC
LIMIT 5;

-- 2. Dead rows by table:
SELECT relname, n_tup_del, n_dead_tup, n_live_tup,
       round(100.0 * n_dead_tup / greatest(n_live_tup, 1), 1) AS dead_pct,
       pg_size_pretty(pg_table_size(relid))   AS heap,
       pg_size_pretty(pg_indexes_size(relid)) AS indexes,
       last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'events';
```

## Open transactions and the horizon

```sql
-- 01_open_transactions.sql
-- Mistake: we still leave transactions open (idle in transaction) and we still run
-- long ones and call them 'just a read'. Same damage, two doors in: the xmin horizon.
-- Part A is the idle-in-transaction case, Part B is everything else that pins the horizon.

----------------------------------------------------------------------------- Part A
-- Mistake: we still leave transactions open while we go do something else.
--
-- What it looks like in the app (Python/psycopg, autocommit off, the default):
--
--   cur.execute("SELECT * FROM orders WHERE id = %s FOR UPDATE", (oid,))
--   charge = payments_api.charge(card, amount)      # 2-30 s over the network
--   cur.execute("UPDATE orders SET status = 'paid' WHERE id = %s", (oid,))
--   conn.commit()
--
-- Between the SELECT and the UPDATE the session is 'idle in transaction'. It
-- holds its row locks and, because FOR UPDATE assigned it a transaction id, it
-- pins the xmin horizon: vacuum cannot remove anything newer than that xid on ANY
-- table in the database. In the default READ COMMITTED it holds no snapshot
-- between statements (backend_xmin is NULL); in REPEATABLE READ it holds both.

-- 1. Who is idle in transaction right now, and for how long?
SELECT pid, usename, application_name, client_addr, state,
       date_trunc('second', now() - xact_start)   AS xact_age,
       date_trunc('second', now() - state_change) AS idle_for,
       backend_xid, backend_xmin,
       greatest(age(backend_xid), age(backend_xmin)) AS horizon_age,
       left(query, 80)                            AS last_statement
FROM pg_stat_activity
WHERE state LIKE 'idle in transaction%'
ORDER BY xact_start;

-- 2. What are they holding? (row locks show as the table's RowExclusive/
--    RowShare lock plus 'transactionid' locks other sessions wait on)
SELECT a.pid, a.state, l.locktype, l.relation::regclass AS relation, l.mode, l.granted
FROM pg_locks l
JOIN pg_stat_activity a USING (pid)
WHERE a.state LIKE 'idle in transaction%'
ORDER BY a.pid, l.relation;

-- 3. Who is stuck behind them?
SELECT w.pid AS waiting_pid, w.wait_event_type, w.wait_event,
       date_trunc('second', now() - w.query_start) AS waiting_for,
       pg_blocking_pids(w.pid) AS blocked_by, left(w.query, 70) AS waiting_query
FROM pg_stat_activity w
WHERE cardinality(pg_blocking_pids(w.pid)) > 0
ORDER BY w.query_start;

-- 4. The fix, server side. Set the timeout above the longest legitimate external
--    call, or give that call its own shorter timeout. A session ended by the
--    timeout gets SQLSTATE 25P03 and must reconnect. Set it on the role, not server-wide, so the
--    reporting user and the migration user can have different limits.
--    (Run these; they are the actual fix, not a demo.)
-- ALTER ROLE app_rw SET idle_in_transaction_session_timeout = '30s';
-- ALTER ROLE app_rw SET transaction_timeout = '5min';     -- PG 17+: caps the whole txn, idle or not

-- 5. The fix, app side: do not open the transaction until the network call is done.
--
--      charge = payments.charge(card, amount, idempotency_key=oid)   # no transaction open
--      with conn.transaction():
--          cur.execute("UPDATE orders SET status = 'paid' WHERE id = %s AND status = 'pending'", (oid,))
--      # on SQLSTATE 25P03: reconnect and retry the UPDATE, never the charge
--
--    The conditional UPDATE replaces the FOR UPDATE guard; the idempotency key
--    keeps a retry from charging twice.
--
-- 5b. Verify: rerun Part A query 1 at peak; expect nothing older than the timeout,
--    and FATAL 25P03 lines in the log grouped by application_name.

----------------------------------------------------------------------------- Part B
-- Mistake: we still run long transactions and assume "it's only a read".
--
-- Any transaction with a snapshot pins the xmin horizon. Dead tuples newer than
-- the oldest snapshot are not removable, on any table, no matter how many times
-- autovacuum runs. The chart charts/vacuum-holdback.svg is this exact run:
-- 3 autovacuum passes while the session was open (7 in the whole run), dead tuples
-- near 45%, zero reclaimed, until the session hit idle_in_transaction_session_timeout.

-- 1. The four places a horizon can be pinned, in one list, oldest first.
--    backend_xid (an open transaction) and backend_xmin (a snapshot) both count.
--    A physical slot's xmin comes from a standby's hot_standby_feedback and pins
--    every table; a logical slot's catalog_xmin pins catalog tuples and retains WAL.
SELECT 'backend'          AS holder, pid::text AS who,
       greatest(age(backend_xid), age(backend_xmin)) AS xmin_age,
       date_trunc('second', now() - xact_start) AS held_for, state AS detail,
       coalesce(nullif(application_name, ''), usename) || ': ' || left(query, 50) AS extra
FROM pg_stat_activity
WHERE (backend_xid IS NOT NULL OR backend_xmin IS NOT NULL)
  AND backend_type = 'client backend' AND pid <> pg_backend_pid()
UNION ALL
SELECT CASE WHEN plugin IS NULL THEN 'physical slot (xmin)' ELSE 'logical slot (catalog_xmin)' END,
       slot_name, greatest(age(xmin), age(catalog_xmin)), NULL,
       CASE WHEN active THEN 'active' ELSE 'INACTIVE' END, coalesce(plugin, 'physical')
FROM pg_replication_slots
WHERE xmin IS NOT NULL OR catalog_xmin IS NOT NULL
UNION ALL
SELECT 'standby (hot_standby_feedback)', application_name, age(backend_xmin), NULL, state, client_addr::text
FROM pg_stat_replication
WHERE backend_xmin IS NOT NULL
UNION ALL
SELECT 'prepared transaction', gid, age(transaction), date_trunc('second', now() - prepared), 'prepared', owner
FROM pg_prepared_xacts
ORDER BY xmin_age DESC NULLS LAST;

-- 2. Proof that vacuum is running but cannot reclaim. VACUUM VERBOSE says it
--    out loud (PG 15+ wording):
--
--    INFO:  vacuuming "app.public.orders"
--    INFO:  finished vacuuming "app.public.orders": index scans: 0
--    tuples: 0 removed, 1483112 remain, 612004 are dead but not yet removable
--    removable cutoff: 982144, which was 61930 XIDs old when operation ended
--
--    "dead but not yet removable" + an old cutoff = somebody is holding a snapshot.
-- VACUUM (VERBOSE) orders;

-- 3. Watch autovacuum spin on it:
SELECT p.pid, p.relid::regclass AS table, p.phase, p.heap_blks_scanned, p.heap_blks_total,
       p.num_dead_item_ids,                       -- PG 17+ (num_dead_tuples before)
       date_trunc('second', now() - a.xact_start) AS running_for
FROM pg_stat_progress_vacuum p JOIN pg_stat_activity a USING (pid);

-- 4. How far behind is the horizon on each table?  n_dead_tup that does not
--    fall after last_autovacuum is the signature.
SELECT schemaname, relname, n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / greatest(n_live_tup, 1), 1) AS dead_pct,
       autovacuum_count, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC
LIMIT 20;

-- 5. Fixes, by holder:
--    backend          -> statement_timeout / transaction_timeout on the role (06_timeouts.sql);
--                        split the batch job into bounded transactions (02_bulk_delete.sql).
--    replication slot -> drop slots nobody consumes: SELECT pg_drop_replication_slot('old_cdc');
--                        cap the damage with max_slot_wal_keep_size; PG 18 adds
--                        idle_replication_slot_timeout to invalidate idle slots for you.
--    standby          -> hot_standby_feedback = on trades primary bloat for fewer
--                        query cancels on the replica. Know which side you chose.
--    prepared xact    -> ROLLBACK PREPARED 'gid'; and ask why XA is on at all
--                        (max_prepared_transactions > 0).

```

## Unused indexes and HOT

```sql
-- 03_indexes.sql
-- Mistake: we build indexes nobody reads, and we index columns that change often.
-- Read-only except the commented-out fixes. PostgreSQL 16+ for last_idx_scan and
-- n_tup_newpage_upd; everything else works on 12+.

-- 1. Indexes with zero scans since the last stats reset, largest first.
--    Excludes unique and primary key indexes and anything backing a constraint.
SELECT s.schemaname, s.relname AS table, s.indexrelname AS index,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
       s.idx_scan, s.last_idx_scan,
       (SELECT stats_reset FROM pg_stat_database WHERE datname = current_database()) AS stats_window_start
FROM pg_stat_user_indexes s
JOIN pg_index i USING (indexrelid)
WHERE s.idx_scan = 0
  AND NOT i.indisunique AND NOT i.indisprimary
  AND NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conindid = s.indexrelid)
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- 2. Exact duplicates: same columns, operator classes, expression and predicate.
SELECT indrelid::regclass AS table,
       array_agg(indexrelid::regclass ORDER BY indexrelid) AS duplicates,
       pg_size_pretty(sum(pg_relation_size(indexrelid))) AS total_size
FROM pg_index
GROUP BY indrelid, indkey::text, indclass::text, coalesce(indexprs::text, ''), coalesce(indpred::text, '')
HAVING count(*) > 1;

-- 3. Invalid indexes left behind by a failed CREATE INDEX CONCURRENTLY.
--    They are maintained on every write and never used by the planner.
SELECT i.indexrelid::regclass AS index, i.indrelid::regclass AS table,
       pg_size_pretty(pg_relation_size(i.indexrelid)) AS size, i.indisvalid, i.indisready
FROM pg_index i
WHERE NOT i.indisvalid OR NOT i.indisready;

-- 4. HOT ratio. A low hot_pct on a busy table means an indexed column is being
--    updated, or the page has no room (fillfactor). The counters are cumulative
--    since stats reset, so a recent regression only shows in a delta: sample twice.
--    n_tup_upd - n_tup_hot_upd - n_tup_newpage_upd = non-HOT updates that stayed
--    on their page, which is the indexed-column case. n_tup_newpage_upd is PG 16+.
SELECT relname, n_tup_upd, n_tup_hot_upd,
       round(100.0 * n_tup_hot_upd / nullif(n_tup_upd, 0), 1) AS hot_pct,
       n_tup_newpage_upd,
       n_dead_tup
FROM pg_stat_user_tables
WHERE n_tup_upd > 0
ORDER BY n_tup_upd DESC
LIMIT 20;

-- 5. Which indexes cover a column that is updated often? Join the hot table from
--    step 4 against pg_index to see which index is disqualifying HOT.
--    (Replace 'pgbench_accounts' and 'abalance'.)
SELECT i.indexrelid::regclass AS index, pg_get_indexdef(i.indexrelid) AS definition
FROM pg_index i
JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
WHERE i.indrelid = 'pgbench_accounts'::regclass AND a.attname = 'abalance';

-- 6. Before dropping anything:
--    - check stats_reset above: a recent reset means the zero is meaningless
--    - run step 1 on every replica; each node counts its own scans
--    - find who wanted it:  git log -S 'ix_pgbench_accounts_abalance' -- db/migrations
--    - find queries that might use it:
--        SELECT queryid, calls, left(query, 80) FROM pg_stat_statements WHERE query ILIKE '%abalance%';
--    - keep the definition so recreating is one statement
--    - if the column must stay indexed, give HOT room instead: ALTER TABLE t SET (fillfactor = 85)
-- SELECT pg_get_indexdef('ix_pgbench_accounts_abalance'::regclass);
-- DROP INDEX CONCURRENTLY ix_pgbench_accounts_abalance;   -- plain DROP INDEX takes ACCESS EXCLUSIVE on the table

-- 7. Verify: after DROP INDEX CONCURRENTLY, step 1 no longer lists it, total index
--    size falls, and hot_pct on the table rises on the next sample.
--
```

## Connections

```sql
-- 05_connection_storm.sql
-- Mistake: we let connection storms reach the database.
-- Connection churn (how fast sessions open and close) is the early signal;
-- connection count against max_connections is the late one.

-- 1. Server-side session counters (PostgreSQL 14+). Sample this twice a minute
--    apart and subtract: (sessions_2 - sessions_1) / 60 is new connections per second.
SELECT datname, sessions, sessions_abandoned, sessions_fatal, sessions_killed,
       xact_commit, stats_reset
FROM pg_stat_database
WHERE datname = current_database();

-- 2. Connections by state and application. Many idle rows means pools larger
--    than the work; many distinct application_name values means no pooler.
SELECT coalesce(nullif(application_name, ''), '(none)') AS application, state, count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY 1, 2
ORDER BY 3 DESC;

-- 3. How close to the ceiling, and how much of it is reserved.
SELECT count(*) AS client_backends,
       current_setting('max_connections')::int AS max_connections,
       current_setting('superuser_reserved_connections')::int AS superuser_reserved,
       current_setting('reserved_connections')::int AS reserved,                 -- PG 16+
       round(100.0 * count(*) / current_setting('max_connections')::int, 1) AS pct_used
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- 4. Age distribution of connections. A storm shows up as many connections
--    younger than a few seconds; a healthy pool shows connections hours old.
SELECT CASE WHEN now() - backend_start < interval '10 seconds' THEN '< 10 s'
            WHEN now() - backend_start < interval '1 minute'   THEN '< 1 min'
            WHEN now() - backend_start < interval '1 hour'     THEN '< 1 hour'
            ELSE '>= 1 hour' END AS connection_age,
       count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY 1
ORDER BY min(now() - backend_start);

-- 4b. sessions_fatal counts sessions that ended on a FATAL error. A connection
--    refused at max_connections never became a session, so it is not counted
--    anywhere in pg_stat_database; it shows only in the server log:
--      FATAL:  sorry, too many clients already
--
-- 5. The fix is outside the database.
--    pgbouncer, transaction mode, server side sized to the database:
--
--      [pgbouncer]
--      pool_mode = transaction
--      default_pool_size = 20            ; toward Postgres, per database/user pair
--      max_client_conn = 5000            ; from the application
--      server_idle_timeout = 60
--      max_prepared_statements = 100     ; pgbouncer 1.21+; psycopg3 auto-prepares after 5 executions
--
--    transaction mode breaks session state: SET (use SET LOCAL), advisory locks,
--    LISTEN/NOTIFY, and server-side prepared statements on older pgbouncer
--    (psycopg: conn.prepare_threshold = None if you cannot upgrade).
--
--    In the client: one pool per process sized to the database's cores, not the
--    application's thread count; connect_timeout in the DSN; backoff with jitter:
--
--      pool = ConnectionPool(DSN, min_size=2, max_size=10, timeout=5)      # psycopg_pool
--      delay = min(30, 0.1 * 2 ** attempt) * random.uniform(0.5, 1.5)      # between reconnects
--
-- 5b. Verify: query 4 shows connections older than an hour and few under 10 s;
--    the sessions delta from query 1 is near zero; the log stops showing
--    "too many clients".

```

## Timeouts

```sql
-- 06_timeouts.sql
-- Mistake: we run without timeouts. Every one of these defaults to 0, meaning unlimited.

-- 1. Current values and where they come from. These are THIS session's values;
--    an administrator's session says nothing about what the application role gets.
SELECT name, setting, unit, source
FROM pg_settings
WHERE name IN ('statement_timeout', 'lock_timeout', 'idle_in_transaction_session_timeout',
               'transaction_timeout',        -- PG 17+
               'idle_session_timeout')       -- PG 14+
ORDER BY name;

-- 2. Per-role and per-database overrides already in place.
SELECT coalesce(r.rolname, '(all roles)') AS role,
       coalesce(d.datname, '(all databases)') AS database,
       s.setconfig
FROM pg_db_role_setting s
LEFT JOIN pg_roles r ON r.oid = s.setrole
LEFT JOIN pg_database d ON d.oid = s.setdatabase
ORDER BY 1, 2;

-- 2b. Login roles with no statement_timeout of their own (the ones to fix first).
SELECT r.rolname
FROM pg_roles r
WHERE r.rolcanlogin AND NOT r.rolsuper AND r.rolname NOT LIKE 'pg\_%'
  AND NOT EXISTS (SELECT 1 FROM pg_db_role_setting s
                  WHERE s.setrole = r.oid AND s.setconfig::text LIKE '%statement_timeout%')
ORDER BY 1;

-- 2c. The symptom, if you have it right now: the longest-running statements.
SELECT pid, usename, application_name, date_trunc('second', now() - query_start) AS running, left(query, 60)
FROM pg_stat_activity
WHERE state = 'active' AND pid <> pg_backend_pid()
ORDER BY query_start
LIMIT 5;

-- 3. Set them per role. Each kind of client gets the limit that fits it.
--    Behind a transaction-mode pooler, role-level settings still apply (they are
--    applied at backend start); session-level SET does not survive the pool.
-- ALTER ROLE app_rw    SET statement_timeout = '30s';
-- ALTER ROLE app_rw    SET lock_timeout = '3s';
-- ALTER ROLE app_rw    SET idle_in_transaction_session_timeout = '30s';
-- ALTER ROLE app_rw    SET transaction_timeout = '5min';          -- PG 17+
-- ALTER ROLE reporting SET statement_timeout = '15min';
-- ALTER ROLE reporting SET idle_in_transaction_session_timeout = '2min';
-- ALTER ROLE migrator  SET lock_timeout = '2s';
-- ALTER ROLE migrator  SET statement_timeout = 0;                 -- long backfills are expected here

-- 4. What a timeout looks like when it fires, so the application can tell them apart:
--    statement_timeout                     SQLSTATE 57014  canceling statement due to statement timeout
--    lock_timeout                          SQLSTATE 55P03  canceling statement due to lock timeout
--    idle_in_transaction_session_timeout   SQLSTATE 25P03  terminating connection due to idle-in-transaction timeout
--    transaction_timeout                   SQLSTATE 25P04  terminating connection due to transaction timeout
--    The last two end the session; the application must reconnect.

-- 4b. Verify: rerun 2b (expect no rows for application roles) and watch the log for
--    57014 / 55P03 / 25P03 / 25P04; the application should handle each of them.
--
```

