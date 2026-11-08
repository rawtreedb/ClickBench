# ClickHouse (S3)

The `clickhouse` entry with the table on S3: `MergeTree` with `storage_policy = 's3'`, an S3 disk
behind a local filesystem cache. Everything else — schema, load, queries — is the same as in
`clickhouse`.

## Setup

- An S3 bucket in the same region as the machine.
- An IAM role attached to the instance with `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` and
  `s3:ListBucket` on the bucket. The server takes the credentials from the instance metadata service
  (`use_environment_credentials`), so no keys are configured.

## Running

```bash
S3_ENDPOINT=https://<bucket>.s3.<region>.amazonaws.com/clickhouse/ ./benchmark.sh
```

Run as root, from a checkout outside a home directory (e.g. `/ClickBench`), like the cloud-init runner does.

The filesystem cache is emptied by `./flush-caches` before every cold run, so the first try of each
query reads from S3. Objects are not deleted from the bucket after the run; clear the prefix with
`aws s3 rm --recursive s3://<bucket>/<prefix>/`.

This entry is not in the daily runs: it needs a bucket and an IAM role.
