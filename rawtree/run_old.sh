#!/bin/bash

TRIES=3

cat queries.sql | while read -r query; do
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

    echo -n "["
    for i in $(seq 1 $TRIES); do
        RES=$(rawtree client --time --format=Null --query="$query" --progress 0 2>&1 ||:)
        [[ $i != 1 ]] && echo -n ", "
        echo -n "${RES}"
    done
    echo "],"
done
