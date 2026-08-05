#!/bin/bash

# Install
aws s3 cp s3://rawtree-ursa-builds/REFs/26.7/812d8b07e3ac476bc5c2818a4d64619bacd2c1e8/build_amd_release/rawtree rawtree
chmod +x rawtree
sudo ./rawtree install --noninteractive

sudo rawtree start

for _ in {1..300}
do
    rawtree-client --query "SELECT 1" && break
    sleep 1
done

# Load the data

rawtree client < create.sql

seq 0 99 | xargs -P100 -I{} bash -c \
    "wget --continue --progress=dot:giga 'https://datasets.clickhouse.com/hits_compatible/athena_partitioned/hits_{}.parquet'"

sudo mv *.parquet /var/lib/rawtree/user_files/
sudo bash -c 'chown rawtree:rawtree /var/lib/rawtree/user_files/*.parquet'

# The four date/time columns are reinterpreted explicitly: hits_*.parquet declares them as plain
# integers (EventDate INT32 logical Int(bitWidth=16, isSigned=false); EventTime/ClientEventTime/
# LocalEventTime INT64 logical None), so there is no date semantics to infer. The typed entries
# recover it from their DDL; with no schema we have to state it. Required for correctness: 7 of the
# 43 queries compare EventDate against date literals, which silently match no rows against UInt16.
echo -n "Load time: "
rawtree client --time --query "
    INSERT INTO hits
    SELECT * REPLACE (
        toDate(EventDate)           AS EventDate,
        toDateTime(EventTime)       AS EventTime,
        toDateTime(ClientEventTime) AS ClientEventTime,
        toDateTime(LocalEventTime)  AS LocalEventTime)
    FROM file('hits_*.parquet')" --max-insert-threads $(( $(nproc) / 4 ))

# Typed ingest
# rawtree client --time --query "INSERT INTO hits FROM file('hits_*.parquet')" --max-insert-threads $(( $(nproc) / 4 ))

# Run the queries

./run_old.sh

echo -n "Data size: "
rawtree client --query "SELECT sum(bytes_on_disk) FROM system.parts WHERE active AND table = 'hits'"
