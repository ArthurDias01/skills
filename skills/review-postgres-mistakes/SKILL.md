---
name: review-postgres-mistakes
description: >-
  Find and fix the Postgres patterns from Scott Mead's talk "The Postgres Mistakes We All Still Make" (shared by Neon on X), in app code, migrations, code reviews, or a live database: a JSONB column that grows on every event; a transaction held open across an HTTP, payment, email, or other network call ("idle in transaction"); a bulk DELETE retention job; unused indexes, or an index on a column every UPDATE changes; connecting per request, or a pool that runs out while the database sits idle; vacuum that cannot remove dead rows; WAL spikes or replica lag after a cleanup job; missing statement, lock, idle-in-transaction, or transaction timeouts. Also use it to decide whether an index is safe to drop. Do not use it for MySQL, general Postgres setup, hosting product questions, or query plan tuning outside these patterns.
---

# Postgres mistakes we all still make

This skill comes from Scott Mead's talk at the NYC Postgres Meetup (November 18, 2026) and the Neon X thread that sums it up. Every source is listed in `references/sources.md`.

The talk has one main idea. Each mistake makes a transaction slower or keeps it open longer, so each one holds a database connection longer. Busy connections fill the pool up to its limit. Callers then wait for a free connection. Raising `max_connections` (the server's connection limit) hides this. Find the work or the wait that holds the connections, and make each transaction cheaper.

## Words used in this skill

- **Row version (tuple)**: one stored copy of a row.
- **MVCC** (multi-version concurrency control): Postgres never overwrites a row in place. An UPDATE writes a new version of the row, so each transaction can still see the version that applies to it.
- **Dead tuple**: an old row version left by an UPDATE or DELETE. It stays on disk until VACUUM removes it, and readers step over it until then.
- **VACUUM / autovacuum**: the cleanup that turns dead tuples into free space. Autovacuum runs it in the background.
- **Bloat**: a table or index that takes more space than its live data needs.
- **Transaction id (xid)** and **snapshot**: a transaction that writes, or runs `SELECT ... FOR UPDATE`, gets an xid. A snapshot is the set of changes a query is allowed to see.
- **Cleanup cutoff (xmin horizon)**: set by the oldest xid or snapshot still in use. VACUUM cannot remove dead tuples newer than the cutoff, on any table in the database. When something keeps the cutoff from moving, we say it "holds back" cleanup.
- **WAL** (write-ahead log): the log of every change. Replicas replay it.
- **HOT update** (heap-only tuple): a cheap UPDATE that writes no new index entries. It only happens when no indexed column changes and the new version fits on the same page.
- **Connection pool**: a set of open connections that the app reuses instead of opening a new one per request.

## How to use this skill

There are two jobs. Pick the one that fits the request.

1. **Review code or schema.** Look for the signs listed under each mistake below. For each hit, quote the line, name the mistake, say why it hurts in one or two sentences, and give the fix. When you find Mistake 2, give both fixes: the app change and the server-side timeout. The timeout is the safety net for code paths the app fix misses.
2. **Check a live database.** Use the read-only queries in `references/detection-queries.md`, or run `scripts/health-check.sql` for a quick scan grouped by severity. The scan covers selected symptoms only, so use the targeted queries to find the cause. Before you trust the results:
   - The role needs `pg_monitor` (or `pg_read_all_stats`). Without it, other sessions' state, query text, and start time show as NULL. Then an empty result means nothing, so say the session checks were incomplete.
   - Run table and index checks in each database. The `pg_stat_user_*` views only cover the current one.
   - Most counters add up over time. Take two samples and compare them. `stats_reset` in `pg_stat_database` tells you when the database counters started. `pg_stat_statements` (the query statistics extension) has its own window.
   - Check the Postgres version, and whether `pg_stat_statements` is installed. `wal_bytes` needs PG 13+. Some other columns need PG 14, 16, or 17. The query file marks them.

The fixes change the database (DROP INDEX, ALTER ROLE, new partitions, VACUUM). Show the user the exact statement and get a yes before you run any of them.

The numbers below come from the talk's own tests. Use them to show the size of a problem. Do not present them as measurements of the user's system.

## Mistake 1: ignoring MVCC

**Signs in code**: a `jsonb` column (Postgres's type for storing JSON) that gets appended to on every event. The talk's example keeps `login_history` inside a `profile` document:

```sql
UPDATE users
   SET profile = jsonb_set(profile, '{login_history}',
                           profile->'login_history' || to_jsonb(now()))
 WHERE id = 1;
```

**Why it hurts**: every update writes the whole document again as a new row version. In the talk, `profile || '{"theme": "light"}'` changed 17 bytes and still rewrote the whole 688-byte row. Each login appended about 24 bytes, so every version was bigger than the last. A document that only grows never fits in the space its last version freed, so the table grows instead. In the talk's one-year example, a reader stepped over 364 dead versions, and one user's row took 221 pages where one page should do. The same query reads more pages and holds its connection longer. Months after the schema choice, the pool opens more connections to keep up.

**Fix**: facts that pile up go in their own table. Recording a login then leaves the users row alone.

```sql
CREATE TABLE login_history (
       user_id       bigint       NOT NULL REFERENCES users (id),
       logged_in_at  timestamptz  NOT NULL DEFAULT now(),
       PRIMARY KEY (user_id, logged_in_at)
);

INSERT INTO login_history (user_id) VALUES (1);
```

A weaker fix, if you only need the latest value: overwrite one fixed-size field (for example `last_login`) instead of appending to a list. In the talk, every version is then the same 110 bytes, so the space VACUUM frees fits the next one. There is still one dead version per update, so VACUUM must keep up, and an open transaction still blocks that cleanup (Mistake 2).

## Mistake 2: leaving transactions open

**Signs in code**: a transaction is opened, then the code makes a network call (a payments API, HTTP, a queue, email) before it commits. The talk's example:

```python
cur.execute("SELECT * FROM orders WHERE id = %s FOR UPDATE", (oid,))
resp = requests.post("https://api.payments-provider.com/v1/charges",
                     json={"card": card, "amount": amount})
cur.execute("UPDATE orders SET status = 'paid' WHERE id = %s", (oid,))
conn.commit()
```

Autocommit means each statement is its own transaction unless the app opens one on purpose. In psycopg2 and psycopg 3, autocommit is off by default, so the first SELECT opens a transaction. JDBC and other drivers differ, so check the driver.

**Why it hurts**: while it waits, the transaction holds the row lock and an xid, and the session shows as "idle in transaction". The xid holds back cleanup on every table. When the API slows down, the waiting requests take every connection in the pool. The pool runs out while the database itself sits idle. Postgres cannot roll back an HTTP call anyway, so the lock never protected the charge.

Other sessions hold back cleanup the same way. A report running for 40 minutes, or `pg_dump`, holds a snapshot even though it only reads. A nightly batch in one transaction holds an xid and a snapshot. A prepared transaction (the first half of a two-phase commit) that nobody finished holds it back until someone commits or rolls it back. A replication slot is the server's record of how far a replica or a change feed has read. A physical slot with `hot_standby_feedback` holds back cleanup on every table. A logical slot that nobody reads holds back cleanup of the system catalog and keeps WAL on disk.

**Fix in the app**: build the pool with autocommit on. Charge first, with no transaction open, and send an idempotency key (a stable request id the payment provider uses to stop a duplicate charge). Check that the provider says the charge worked. Then run one UPDATE that only changes a pending order. That status check replaces the row lock. Any other SQL goes in one short transaction with no network call inside it. The talk's version:

```python
# the pool is built once at startup with autocommit on, for example
# psycopg_pool.ConnectionPool(DSN, min_size=2, max_size=10, kwargs={"autocommit": True})
conn = pool.getconn()

# the charge runs with no transaction open
resp = requests.post("https://api.payments-provider.com/v1/charges",
                     headers={"Idempotency-Key": f"order-{oid}"},
                     data={"amount": amount, "currency": "usd",
                           "customer": cust, "confirm": "true"}, timeout=30)

cur.execute("UPDATE orders SET status = 'paid' "
            "WHERE id = %s AND status = 'pending'", (oid,))

# the only transaction. SQL only, milliseconds
with conn.transaction():
    cur.execute("INSERT INTO ledger ...")
    cur.execute("UPDATE balances ...")
```

Return the connection to the pool (`putconn`) in a `finally` block.

If a timeout ends the session, reconnect and retry the UPDATE, never the charge. The `status = 'pending'` check is what makes that retry safe: a second run changes nothing. Postgres reports each timeout with an error code (SQLSTATE): 57014 for `statement_timeout` and 55P03 for `lock_timeout` cancel the statement only, while 25P03 (idle in transaction) and 25P04 (transaction timeout) end the session.

**Fix on the server**: these five timeouts all default to 0, which means a connection can be held forever: `statement_timeout`, `lock_timeout`, `idle_in_transaction_session_timeout`, `transaction_timeout` (PG 17), and `idle_session_timeout` (PG 14). Set them per role, because the app, the reports, and the migrations need different limits:

```sql
ALTER ROLE app_rw SET idle_in_transaction_session_timeout = '30s';
ALTER ROLE app_rw SET transaction_timeout = '5min';   -- PG 17+
```

Pick the number from your commit rate. At 300 commits a second, a 30-second wait lets 9,000 transactions commit while cleanup is held back. A pooler such as PgBouncer in transaction mode hands a server connection back to the pool after each transaction. Role settings still apply there. A session-level `SET` does not survive the pool (use `SET LOCAL`), and advisory locks and `LISTEN` break too.

**Check**: run the "who holds the cleanup cutoff" query in `references/detection-queries.md`. In vacuum logs, "dead but not yet removable" with an old removable cutoff means something holds the cutoff back.

## Mistake 3: bulk DELETE instead of partitioning

**Signs in code**: a nightly retention job on a big table, like:

```sql
DELETE FROM events WHERE created_at < now() - interval '90 days';
```

**Why it hurts**: DELETE only marks rows dead. On a large table it is one transaction that can stay open for hours, which holds back cleanup everywhere (Mistake 2). It writes WAL for every row, and every standby replays it, so you see replication lag and a WAL spike at the same time each night. VACUUM then has to scan every index to remove the dead entries, and the index pages it empties stay allocated for reuse.

**Fix**: split the table into partitions, each holding one date range. When a whole partition is past the retention cutoff, detach it and drop it. That removes it as a unit, with no dead rows and almost no WAL. The talk's migration:

```sql
-- the key must include created_at
CREATE TABLE events_p (LIKE events INCLUDING DEFAULTS, PRIMARY KEY (id, created_at))
  PARTITION BY RANGE (created_at);
CREATE TABLE events_p_2026_08 PARTITION OF events_p FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
-- one partition per month back to the retention edge, indexes on events_p
-- pg_partman (an extension that creates and drops partitions on a schedule) can keep the calendar
INSERT INTO events_p SELECT * FROM events WHERE created_at >= '2026-08-01' AND created_at < '2026-09-01';   -- a month per batch
SET lock_timeout = '2s';
BEGIN; ALTER TABLE events RENAME TO events_old; ALTER TABLE events_p RENAME TO events; COMMIT;

-- from now on, retention:
ALTER TABLE events DETACH PARTITION events_p_2026_08 CONCURRENTLY;
DROP TABLE events_p_2026_08;
```

This shows the pattern, not a full migration. When you adapt it:
- Create every partition back to the retention edge, plus partitions for new writes, and build the indexes on the new table.
- The primary key becomes `(id, created_at)`. Check that this still gives the uniqueness the app needs.
- Rows inserted, updated, or deleted after a batch was copied must reach the new table. Stop writes for the final copy and the swap, or capture the changes and apply them at the swap.
- A partition can only be dropped when its whole range is past the cutoff. If the cutoff must be exact, pick partition sizes that fit it.
- `DETACH PARTITION ... CONCURRENTLY` needs PG 14+, cannot run inside a transaction block, waits for open transactions on the table, and fails if the table has a default partition.

**Until you can partition**: delete in bounded batches and commit each one, let autovacuum keep up, and run `REINDEX CONCURRENTLY` afterwards where the indexes need it.

**Check**: in `pg_stat_statements`, compare `calls`, `rows`, and `wal_bytes` before and after the job. The talk's clues are one statement with `wal_bytes` over 1 GB and `rows` in the millions. In `pg_stat_user_tables`, look for `n_dead_tup` above a fifth of `n_live_tup` with `last_autovacuum` hours old. After the switch, `n_tup_del` on the parent should stay flat during retention.

## Mistake 4: unused indexes

**Signs in code**: migrations that add indexes no query reads, or an index on a column that every UPDATE changes (the talk's example is an account balance).

**Why it hurts**: every index adds work to every INSERT and to every UPDATE that is not HOT. Indexing a column that every UPDATE changes turns HOT off for those updates, so each one writes index entries and leaves a dead tuple behind. In the talk's test on 1M rows, an UPDATE wrote 2 pages with only a primary key and 9 pages with seven extra indexes, and WAL per UPDATE went from 311 B to 855 B. At that size the UPDATE still took 0.2 ms, because everything was in memory. At larger sizes the indexes compete with the table for memory, and slower writes hold their connection longer.

**Check before you drop anything**:
1. Find indexes with zero scans (query in `references/detection-queries.md`). Skip unique, primary key, and constraint indexes. The talk's slide flags zero scans with more than 100 MB on disk. Also look for invalid indexes left by a failed `CREATE INDEX CONCURRENTLY`: they are kept up to date on every write and never used.
2. Zero counts only since `stats_reset`. A recent reset or a short window proves nothing. Cover rare jobs like monthly reports.
3. Each replica counts its own scans. Check every node.
4. Find who added it (`git log -S '<index name>'`) and look for queries that might use it in `pg_stat_statements`.
5. Watch the HOT ratio, the share of updates that were HOT. `n_tup_hot_upd` under half of `n_tup_upd` means an indexed column is updated or the page is full. Compare two samples, since the counters add up.

**Fix**: save the definition first, then drop it with `CONCURRENTLY`. A plain `DROP INDEX` takes an ACCESS EXCLUSIVE lock, the strongest table lock, which blocks all reads and writes on the table while it runs.

```sql
SELECT pg_get_indexdef('ix_name'::regclass);
DROP INDEX CONCURRENTLY ix_name;
```

If HOT fails because pages are full, a lower fillfactor (the share of each page Postgres fills on insert) leaves room, for example `ALTER TABLE t SET (fillfactor = 85)`. That does not help when the update changes an indexed column.

**Verify**: the index is gone from `pg_index` and total index size falls. If the dropped index was the one blocking HOT, the HOT ratio rises on the next sample.

## Also from the talk: connections

**Cause**: Postgres runs one process per connection. Each new connection costs a fork, memory, authentication, and a cold catalog cache before any row is touched. A high count is one problem. A high rate of new connections grinds the whole server. In the talk's test, persistent connections ran 215 thousand transactions a second at 0.09 ms each. Connecting per transaction ran 1,415, and half of each 14 ms transaction was the connect.

**Signs in code**: a new `connect()` per request with no pool, or reconnecting with no delay. A storm is many clients retrying at the same moment. The talk's backoff spreads them out: `delay = min(30, 0.1 * 2**attempt) * uniform(0.5, 1.5)`.

**Fix**: create a pool once at startup and borrow connections from it. The talk shows psycopg2 `pool.ThreadedConnectionPool`, and says the same pattern applies in psycopg 3, HikariCP (Java), and `database/sql` (Go). Apps can use their own pool, PgBouncer, or both.

**Check**: on PG 14+, sample `sessions` in `pg_stat_database` twice, a minute apart. The difference is the rate of new connections. Many connections younger than a few seconds also point to churn. The queries are in `references/detection-queries.md`.

## How to report

For a code review, give one entry per finding:

- **Mistake**: which one (1 to 4, connections, or timeouts).
- **Where**: file and line, quoted.
- **Why it hurts**: one or two sentences, tied to connections where it fits.
- **Fix**: the change, with code.

For a live database, list findings worst first (critical, then warning, then info). The health check also reports transaction id age (`age(datfrozenxid)` over 1 billion). Postgres shuts down to protect itself at about 2.1 billion, so treat that row as urgent. Say which checks you could not run and why (missing role, old version, no `pg_stat_statements`).

Do not suggest raising `max_connections` as the fix. It hides the cause.
