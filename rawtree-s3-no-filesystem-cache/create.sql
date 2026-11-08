-- No schema: RawMergeTree derives every column from the inserted data and its own sorting key.
CREATE OR REPLACE TABLE hits(__raw_data JSON CODEC(ZSTD(3))) ENGINE = RawMergeTree
ORDER BY (CounterID, EventDate, UserID, EventTime, WatchID)
SETTINGS
    storage_policy = 's3',
    fsync_after_insert = 1; -- https://github.com/ClickHouse/ClickBench/issues/678