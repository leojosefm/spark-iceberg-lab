# Spark Iceberg Lab

A hands-on project for learning Apache Spark, Apache Iceberg, Hive Metastore and object storage from the ground up.

The goal of this repository is **not** just to create Iceberg tables.

The goal is to understand exactly what happens behind every SQL statement.

After every operation we inspect:

- Spark execution
- Iceberg metadata
- Snapshot history
- Manifest files
- Manifest lists
- Parquet files
- Hive Metastore
- PostgreSQL metadata
- MinIO object storage

By the end of this project you should understand how Iceberg implements ACID transactions, time travel, schema evolution and snapshot isolation.


# Technology Stack

| Component | Purpose |
|------------|---------|
| Apache Spark | Distributed processing engine |
| PySpark | Python API for Spark |
| Apache Iceberg | Open table format |
| Hive Metastore | Metadata service |
| PostgreSQL | Hive Metastore backend database |
| MinIO | S3-compatible object storage |
| JupyterLab | Development environment |
| Docker Compose | Local infrastructure |

---

# Repository Structure

```
spark-iceberg-lab/

docker-compose.yml

README.md

jupyter/
spark/
hive/
postgres/
minio/

datasets/

notebooks/

lessons/

sql/
```

---

# Learning Path

## Part 1

Spark Fundamentals

- Spark Architecture
- Driver
- Executors
- Cluster Manager
- DAG
- Lazy Evaluation
- Catalyst Optimizer

---

## Part 2

Object Storage

- Why Spark prefers object storage
- MinIO
- Buckets
- Parquet files

---

## Part 3

Hive Metastore

- What is metadata?
- Hive Metastore Service
- PostgreSQL Metadata Database
- Spark Catalog

---

## Part 4

Apache Iceberg

- Iceberg Catalog
- Metadata JSON
- Manifest Lists
- Manifest Files
- Snapshots
- Table Versions

---

## Part 5

Creating Tables

```
CREATE TABLE
```

Learn

- Which files are created
- What is written into metadata.json
- What PostgreSQL stores
- What Hive Metastore stores

---

## Part 6

Insert

```
INSERT INTO
```

Learn

- New snapshot creation
- New manifest list
- New Parquet files
- Metadata updates

---

## Part 7

Update

```
UPDATE
```

Learn

- Copy-on-write
- Merge-on-read
- Delete files
- Snapshot replacement

---

## Part 8

Delete

```
DELETE
```

Learn

- Position Deletes
- Equality Deletes
- Snapshot changes

---

## Part 9

Merge

```
MERGE INTO
```

Learn

- Upserts
- Row level operations
- Snapshot generation

---

## Part 10

Schema Evolution

```
ALTER TABLE
```

Learn

- Add column
- Rename column
- Drop column
- Type promotion

---

## Part 11

Partition Evolution

Learn

- Hidden Partitioning
- Partition Spec
- Partition Evolution

---

## Part 12

Time Travel

```
SELECT ...
VERSION AS OF
```

Learn

- Snapshot history
- Reading historical data

---

## Part 13

Rollback

Restore an older snapshot and understand how Iceberg switches table versions without rewriting data.

---

## Part 14

Maintenance

- Rewrite Data Files
- Rewrite Manifests
- Expire Snapshots
- Remove Orphan Files

---

# What You Will Learn

After completing this repository you should be able to answer questions such as:

- What happens after CREATE TABLE?
- Where are Iceberg tables stored?
- What is metadata.json?
- What is a snapshot?
- Why are manifest files required?
- Why doesn't Iceberg update Parquet files?
- How does UPDATE work?
- How does DELETE work?
- How does Time Travel work?
- How does Rollback work?
- What happens during snapshot expiration?
- Why is Hive Metastore needed?
- What does PostgreSQL actually store?
- How does Spark find an Iceberg table?
- Why can multiple query engines read the same Iceberg table?

---

# References

- Apache Iceberg Official Documentation
- Apache Spark Documentation
- Apache Iceberg Table Specification