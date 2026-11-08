# ClickHouse (S3, no filesystem cache)

The `clickhouse-s3` entry without the local filesystem cache: the S3 disk is used directly by
`storage_policy = 's3'`, so every read goes to S3, the warm runs included. The difference between
the two entries is what the cache contributes. Everything else — schema, load, queries — is the same
as in `clickhouse`.

## Setup

- An S3 bucket in the same region as the machine.
- An IAM role attached to the instance with `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` and
  `s3:ListBucket` on the bucket. The server takes the credentials from the instance metadata service
  (`use_environment_credentials`), so no keys are configured.

## Running

```bash
S3_ENDPOINT=https://<bucket>.s3.<region>.amazonaws.com/clickhouse-no-cache/ ./benchmark.sh
```

Run as root, from a checkout outside a home directory (e.g. `/ClickBench`), like the cloud-init runner does.

There is no `flush-caches`: reads from S3 do not go through the OS page cache, and there is no other
cache to drop. Objects are not deleted from the bucket after the run; clear the prefix with
`aws s3 rm --recursive s3://<bucket>/<prefix>/`.

This entry is not in the daily runs: it needs a bucket and an IAM role.
