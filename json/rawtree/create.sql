-- Schema-less RawMergeTree engine with specified primary key
CREATE TABLE bluesky ENGINE = RawMergeTree
ORDER BY (
    kind,
    commit.operation,
    commit.collection,
    did,
    fromUnixTimestamp64Micro(time_us))
