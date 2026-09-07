# Spark + Iceberg Learning Lab

A local Docker-based environment for learning Apache Iceberg with Spark, progressing
from a file-based ("hadoop") catalog to a full Hive Metastore-backed catalog.

---

## 1. Architecture

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  spark-notebook   │      │  hive-metastore    │      │  hive-postgres    │
│  (Spark + Jupyter)│─────►│  (Thrift, :9083)   │─────►│  (Postgres :5432) │
│  :8888 / :4040     │      └──────────────────┘      └─────────────────┘
└─────────────────┘
        │
        ▼
  /data/warehouse   (bind mount — actual Parquet + Iceberg metadata files)
  /data/raw         (bind mount — source raw parquet)
```

- **spark-notebook**: runs Spark locally (`local[*]`) inside a JVM, with Jupyter Lab
  as the notebook interface. Also hosts the Spark UI on port 4040 while a session is active.
- **hive-metastore**: a Thrift service (Apache Hive standalone metastore) that stores
  *pointers* to Iceberg tables' current metadata — not the data itself.
- **hive-postgres**: the relational database backing the Hive Metastore's own schema
  (`DBS`, `TBLS`, `SDS`, `COLUMNS_V2`, etc.)
- **/data/warehouse**: where all actual table content lives — Parquet data files,
  Iceberg manifests, manifest lists, and `metadata.json` files. This is true
  regardless of catalog type (hadoop or hive) — the catalog only decides how the
  "current version" pointer is tracked, never where the files live.

---

## 2. Notebooks

### `iceberg-learning-localpointer.ipynb`
First notebook — introduces core Iceberg concepts using the **hadoop catalog**
(`spark.sql.catalog.local.type = hadoop`), which requires no external services —
just a filesystem path (`/data/warehouse`). Good for learning Iceberg internals
without also debugging a metastore connection.

Covers:
- Reading dummy/fake machine log data (`machine-raw-log-anonymized.parquet`),
  simple aggregations
- Writing an Iceberg table (`local.db.merged_logs`)
- Inspecting the resulting file layout:
  ```
  /data/warehouse/db/merged_logs/
  ├── data/
  │   └── *.parquet                     ← actual rows
  └── metadata/
      ├── version-hint.text             ← plain text file: which version is "current"
      ├── v1.metadata.json              ← table schema + snapshot history, version 1
      ├── v2.metadata.json              ← version 2, after next write/update/delete
      ├── snap-<snapshot-id>-*.avro     ← manifest list (= one snapshot)
      └── <uuid>-m0.avro, ...           ← manifests (= list of data files + stats)
  ```
  **The "what was the JSON file called" answer:** under the hadoop catalog, each
  commit produces a new `vN.metadata.json` (`v1.metadata.json`, `v2.metadata.json`,
  ...), and `version-hint.text` is a plain integer telling readers which `N` is
  currently active. Iceberg swaps this pointer atomically (via filesystem rename)
  on every commit.
- UPDATE/DELETE mechanics: copy-on-write vs. merge-on-read, and what each does to
  the file layout above
- Table maintenance: `rewrite_data_files`, `rewrite_manifests`, `expire_snapshots`,
  `remove_orphan_files`

### `iceberg-hive-metastore.ipynb`
Second notebook — switches the catalog type to **hive**, backed by the
`hive-metastore` + `hive-postgres` services. Same Iceberg SQL/DataFrame API as
before; only the catalog config changes (see Section 4).

Covers:
- Creating databases/tables through the Hive Metastore
  (`CREATE DATABASE IF NOT EXISTS machine.bronze`, etc.)
- What Hive Metastore actually stores vs. what stays in `metadata.json` on disk
  (see Section 5 below for the full breakdown)
- Inspecting the Postgres-backed metastore schema directly via `psql`

### `query-iceberg.ipynb`
Third notebook — a read-focused playground against tables built in the earlier
two notebooks. Covers:
- Basic `SELECT` queries
- Iceberg metadata tables: `.snapshots`, `.history`, `.files`, `.manifests`, `.changes`
- Time travel: `VERSION AS OF <snapshot_id>`, `TIMESTAMP AS OF '<ts>'`
- CDC-style change reads via `.changes` with `start-snapshot-id`/`end-snapshot-id`
  reader options (note: bounds must be direct ancestors in the snapshot lineage —
  `createOrReplace()` resets lineage, so old/new snapshots across a replace aren't
  linked)

See Section 6 for a query cheat-sheet.

---

## 3. Jupyter / Docker setup

### Bring the stack up (in order, to avoid startup races)
```bash
cd /path/to/spark-iceberg-lab   # must run from the folder containing docker-compose.yml
docker compose up -d postgres
# wait a few seconds for Postgres to accept connections
docker compose up -d hive-metastore
docker logs hive-metastore --tail 30   # confirm clean startup, no schema errors
docker compose up -d notebook
```

### Access points
- Jupyter Lab: http://localhost:8888/lab
- Spark UI (only while a SparkSession is active in the notebook): http://localhost:4040
- Hive Metastore Thrift port (not browsable — binary protocol, not HTTP): `localhost:9083`
- Postgres (host access): `localhost:5433` (internal container-to-container port is `5432`)

### Common gotchas hit while setting this up
- **Named volumes (`ivy-cache`, and any fresh bind-mount target Docker creates)
  can end up owned by `root`**, causing `PermissionError`/403 errors when Jupyter
  or Ivy try to write. Fix:
  ```bash
  docker exec -u root spark-notebook chown -R jmattam:jmattam <path>
  ```
  This is now handled automatically on every container start via `entrypoint.sh`
  (see `docker/base/entrypoint.sh`) — it `chown`s the known mount points before
  dropping to the `jmattam` user.
- **`./notebooks` relative path resolves from wherever you run `docker compose`**,
  not from the project folder by assumption — always `cd` into the project root
  first, or you'll get an unexpected empty mount.
- **`.getOrCreate()` silently reuses an existing SparkSession** if one is already
  alive in the kernel, ignoring any new `.config(...)` calls in the cell you just
  ran. If you change catalog config and nothing seems to take effect, restart the
  kernel (or `spark.stop()`) before rerunning.
- **`spark-warehouse` appearing in `./notebooks`** is expected — it's Spark's own
  default-catalog (`spark_catalog`) warehouse directory, created automatically the
  moment a SparkSession starts, completely unrelated to the Iceberg catalogs
  (`local`/`machine`) actually used in this project. Harmless; can be redirected
  via `spark.sql.warehouse.dir` if it's distracting.

---

## 4. Catalog configs used across notebooks

**Hadoop catalog** (`iceberg-learning-localpointer.ipynb`):
```python
.config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog")
.config("spark.sql.catalog.local.type", "hadoop")
.config("spark.sql.catalog.local.warehouse", "/data/warehouse")
```

**Hive catalog** (`iceberg-hive-metastore.ipynb`, `query-iceberg.ipynb`):
```python
.config("spark.sql.catalog.machine", "org.apache.iceberg.spark.SparkCatalog")
.config("spark.sql.catalog.machine.type", "hive")
.config("spark.sql.catalog.machine.uri", "thrift://hive-metastore:9083")
.config("spark.sql.catalog.machine.warehouse", "/data/warehouse")
```
Note: `local`/`machine`/`hive_cat` are arbitrary Spark-session-local aliases —
they are never sent to or stored in the metastore. Only the `database.table`
portion of any identifier corresponds to real, persisted catalog entries.

---

## 5. Hive Metastore internals — what each Postgres table means

The metastore's own schema, in `hive-postgres` (database `metastore`). Access via:
```bash
docker exec -it hive-postgres psql -U hive -d metastore
```
All identifiers are case-sensitive and must be double-quoted (e.g. `"DBS"`), since
the schema was created with mixed-case names.

| Table | What it stores | Roughly equivalent to |
|---|---|---|
| `"CTLGS"` | Hive Metastore's own internal multi-catalog feature. Always shows one row, `NAME = 'hive'`, the built-in default. **Unrelated to Spark's catalog names** (`local`/`machine`) — pure naming coincidence, never touched in this project. | Not applicable to Iceberg usage here |
| `"DBS"` | One row per database (`bronze`, `silver`, `raw`, `default`, ...). Columns include `NAME` and `DB_LOCATION_URI` (the physical folder, e.g. `.../silver.db`). | `CREATE DATABASE` registry |
| `"TBLS"` | One row per table (`agg_raw_log`, `machine_raw_log`, ...). Links to a database via `DB_ID`, and to a storage descriptor via `SD_ID`. | Table registry |
| `"SDS"` | Storage descriptors — physical `LOCATION`, input/output format, per table. Joined to `TBLS` via `SD_ID`. | Physical location + format info |
| `"COLUMNS_V2"` | Column names/types, as last known by the metastore. **A cached, informational copy only** — the real source of truth for schema (including full schema history) is always the table's `metadata.json` in `/data/warehouse`, never this table. | Cached schema snapshot |

**The one thing that actually matters for Iceberg specifically:** none of the
above tables store your table's *current pointer* directly as a dedicated column
in this list — that lives as a **table property** attached to the `TBLS`/`SDS`
entry (conceptually equivalent to Glue's `Parameters.metadata_location` field),
pointing at the current `metadata.json` path. Everything else — schema, snapshot
history, manifests — is derived by reading that file, not stored relationally
in Postgres.

**Big picture:** Hive Metastore is a thin, transactional *pointer* layer. All
real table content (data + full metadata history) lives as files under
`/data/warehouse`, identically in shape whether the catalog type is `hadoop`,
`hive`, `glue`, or `rest` — only the pointer-tracking mechanism changes.

---

## 6. Querying Iceberg (`query-iceberg.ipynb`)

```python
# Basic read
spark.sql("SELECT * FROM machine.silver.agg_raw_log LIMIT 5").show()

# Snapshot history
spark.sql("SELECT * FROM machine.silver.agg_raw_log.snapshots").show(truncate=False)

# "Current as of when" lineage view
spark.sql("SELECT * FROM machine.silver.agg_raw_log.history").show(truncate=False)

# Time travel — by snapshot id
spark.sql("SELECT * FROM machine.silver.agg_raw_log VERSION AS OF <snapshot_id>").show()

# Time travel — by timestamp
spark.sql("SELECT * FROM machine.silver.agg_raw_log TIMESTAMP AS OF '2026-09-06 20:56:00'").show()

# Row-level changes between two snapshots (must be direct ancestors)
spark.read.format("iceberg") \
    .option("start-snapshot-id", "<older_id>") \
    .option("end-snapshot-id", "<newer_id>") \
    .load("machine.silver.agg_raw_log.changes") \
    .show(truncate=False)

# Physical data files backing the current snapshot
spark.sql("SELECT * FROM machine.silver.agg_raw_log.files").show(truncate=False)

# Manifests (one level above files)
spark.sql("SELECT * FROM machine.silver.agg_raw_log.manifests").show(truncate=False)

# Maintenance
spark.sql("CALL machine.system.rewrite_data_files('silver.agg_raw_log')")
spark.sql("CALL machine.system.rewrite_manifests('silver.agg_raw_log')")
spark.sql("CALL machine.system.expire_snapshots(table => 'silver.agg_raw_log', retain_last => 3)")
spark.sql("CALL machine.system.remove_orphan_files('silver.agg_raw_log')")
```

---
