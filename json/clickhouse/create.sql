-- Only the JSON column, with its default settings: the sort key casts the paths it needs,
-- as the other systems extract them (see ../starrocks/create.sql).
CREATE TABLE bluesky
(
    `data` JSON
)
ORDER BY (
    data.kind::String,
    data.commit.operation::String,
    data.commit.collection::String,
    data.did::String,
    fromUnixTimestamp64Micro(data.time_us::UInt64))
