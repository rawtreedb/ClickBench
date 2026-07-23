-- No schema: RawMergeTree derives every column from the inserted data and its own sorting key.
CREATE TABLE hits ENGINE = RawMergeTree
SETTINGS
    min_bytes_for_wide_part = 1073741824, -- the default in ClickHouse Cloud and RawTree Cloud
    fsync_after_insert = 1; -- https://github.com/ClickHouse/ClickBench/issues/678
