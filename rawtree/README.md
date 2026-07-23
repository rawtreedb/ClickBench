# RawTree

RawTree runs ClickBench in `RawMergeTree` mode: the table is created with no schema at all, and the
dataset is ingested straight from the parquet files.

```sql
CREATE TABLE hits ENGINE = RawMergeTree;
INSERT INTO hits SELECT * FROM file('hits_*.parquet');
```

There is no column list, no type, no `ORDER BY` and no `PRIMARY KEY`. Every parquet column becomes a
dynamic path of the implicit `__raw_data JSON` column, keeping its concrete type, and the sorting key
is derived per part. Queries then reference the columns by their plain names, so the point of this
entry is to measure what the dynamic columns cost against the same 43 queries the typed
`clickhouse` entry runs.

## Running

`benchmark.sh` is the entry point for a real run on a fresh VM, driven by `../lib/benchmark-common.sh`
like the other entries. It installs RawTree, so point it at a binary first:

```bash
RAWTREE_BINARY=/path/to/rawtree ./benchmark.sh
```

`run-local.sh` runs the benchmark against a server that is already running, using the client in
PATH. It ingests the data, runs the queries and writes `results/<date>/<machine>.json` — nothing is
installed, started or stopped, which makes it the one to use for profiling the queries:

```bash
./run-local.sh                       # download, ingest, run
SKIP_DOWNLOAD=1 SKIP_LOAD=1 ./run-local.sh   # reuse the data already loaded
```

See the header of the script for the rest of the settings.

## Deviations from the other entries

- `install` takes the binary from `RAWTREE_BINARY` (a local build) or `RAWTREE_BINARY_URL`, because
  RawTree has no public install script yet. Everything after that is a normal distribution install.
- Query 41 casts one argument — `TraficSourceID::Int64 IN (-1, 6)` — because `IN` does not accept a
  `Dynamic` argument. The other 42 queries are the stock ClickBench queries, unmodified.
- `min_bytes_for_wide_part = 1073741824` matches the RawTree Cloud and ClickHouse Cloud default, so
  the parts are compact at this dataset size.
