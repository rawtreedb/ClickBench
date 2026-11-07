-- No schema: RawMergeTree derives every column from the inserted data and its own sorting key.
CREATE OR REPLACE TABLE hits ENGINE = RawMergeTree
SETTINGS
    min_bytes_for_wide_part = 1,
    pack_object_columns_on_insert = 1,
    vertical_merge_parallelize = 1,
    fsync_after_insert = 1; -- https://github.com/ClickHouse/ClickBench/issues/678
