#!/bin/bash

# ClickBench for RawTree against a server that is already running: ingest, run the queries, write
# the results. Not part of the ClickBench contract — `benchmark.sh` is the entry point for a real
# run on a fresh VM. This one is for running the benchmark locally and for profiling the queries.
#
# Everything is done through the client in PATH, so nothing is installed, started or stopped.
#
#   CLIENT      client to run the queries with.  Default `rawtree-client`, or `rawtree client`.
#   TRIES       runs per query.                  Default 3
#   PARQUET     files to ingest.                 Default hits_*.parquet
#   MACHINE     name of the results file.        Default the EC2 instance type, else `local`
#   SKIP_DOWNLOAD, SKIP_LOAD
#               set to 1 to reuse the parquet files / the `hits` table already there.
#
# Writes the timings to stdout and to results/<date>/<machine>.json.

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ -z "${CLIENT:-}" ]; then
    if command -v rawtree-client >/dev/null 2>&1; then
        CLIENT="rawtree-client"
    elif command -v rawtree >/dev/null 2>&1; then
        CLIENT="rawtree client"
    else
        echo "benchmark: no rawtree-client in PATH — set CLIENT to a client to use" >&2
        exit 1
    fi
fi

TRIES="${TRIES:-3}"
PARQUET="${PARQUET:-hits_*.parquet}"
MACHINE="${MACHINE:-$(curl -s --max-time 1 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo local)}"

# $CLIENT is deliberately unquoted: it may be two words (`rawtree client`).
client() {
    $CLIENT "$@"
}

client --query "SELECT 1" >/dev/null || { echo "benchmark: no server to talk to" >&2; exit 1; }

# Download the data

if [ "${SKIP_DOWNLOAD:-0}" != "1" ]; then
    seq 0 99 | xargs -P100 -I{} bash -c \
        "wget --continue --progress=dot:giga 'https://datasets.clickhouse.com/hits_compatible/athena_partitioned/hits_{}.parquet' 2>&1 | tail -1"
fi

# Load the data

if [ "${SKIP_LOAD:-0}" != "1" ]; then
    client --multiquery < create.sql

    # `file()` reads from the server's user_files directory, so the parquet files have to be
    # reachable from there. Symlink rather than move: mv of the whole dataset would copy 14 GB the
    # server reads once. `chown -h` sets the symlink's owner without following it, which is enough
    # because the parquet files themselves are readable.
    # No such directory means the client reads the files itself (`rawtree local`), so leave them be.
    USER_FILES="$(client --query "SELECT value FROM system.server_settings WHERE name = 'user_files_path'" 2>/dev/null || true)"
    [ -d "${USER_FILES:-}" ] || USER_FILES=""
    if [ -n "$USER_FILES" ]; then
        for f in $PARQUET; do
            sudo ln -sf "$PWD/$f" "$USER_FILES/$f"
        done
        sudo chown -h rawtree:rawtree "$USER_FILES"/$PARQUET 2>/dev/null || true
    fi

    # No column list and no schema: every parquet column becomes a dynamic path of `__raw_data`,
    # keeping its concrete type.
    load_start=$(date +%s.%N)
    client --query "INSERT INTO hits SELECT * FROM file('$PARQUET')" \
        --max-insert-threads "$(( $(nproc) / 4 ))"
    sync
    load_end=$(date +%s.%N)
    load_time=$(awk -v s="$load_start" -v e="$load_end" 'BEGIN { printf "%.3f", e - s }')

    if [ -n "$USER_FILES" ]; then
        sudo rm -f "$USER_FILES"/$PARQUET
    fi
else
    load_time=null
fi

echo "Load time: $load_time"

# Run the queries

results=()
num=0
while IFS= read -r query; do
    [ -z "$query" ] && continue
    num=$((num + 1))

    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

    tries=()
    echo -n "["
    for i in $(seq 1 "$TRIES"); do
        # --time prints the fractional seconds to stderr, --format=Null discards the result.
        # stdin is closed because this loop holds queries.sql open on it, and the client would
        # otherwise read it as an input table.
        res=$(rawtree client --time --format=Null --progress 0 --query "$query" 2>&1 </dev/null) || res="null"
        # Keep only the timing: an error would otherwise end up in the JSON.
        [[ "$res" =~ ^[0-9]+(\.[0-9]+)?$ ]] || res="null"
        [ "$i" != 1 ] && echo -n ", "
        echo -n "$res"
        tries+=("$res")
    done
    echo "],"

    results+=("$(IFS=,; echo "[${tries[*]}]")")
done < queries.sql

data_size=$(client --query "SELECT total_bytes FROM system.tables WHERE name = 'hits' AND database = 'default'")
echo "Data size: $data_size"

# Generate the results file

mkdir -p "results/$(date -u +%Y%m%d)"
result_file="results/$(date -u +%Y%m%d)/${MACHINE}.json"

RESULT="[$(IFS=,; echo "${results[*]}")]" \
LOAD_TIME="$load_time" DATA_SIZE="$data_size" MACHINE="$MACHINE" DATE="$(date -u +%F)" \
python3 -c '
import json, os

result = json.load(open("template.json"))
result["date"] = os.environ["DATE"]
result["machine"] = os.environ["MACHINE"]
result["cluster_size"] = 1
result["load_time"] = json.loads(os.environ["LOAD_TIME"])
result["data_size"] = int(os.environ["DATA_SIZE"])
result["result"] = json.loads(os.environ["RESULT"])
print(json.dumps(result, indent=4))
' > "$result_file"

echo "Results: $result_file"
