# Summary
This is a highly-available PostgreSQL cluster using the excellent [CloudNativePG Operator](https://cloudnative-pg.io/). Its configured as a 3-node cluster using local storage. It has live replication to a [remote PostgreSQL server running on Oracle Cloud](https://github.com/kenlasko/k8s-cloud/tree/main/manifests/database/postgresql).

## Backups
Constant backups are being made to a remote S3 bucket, which makes restoration very simple.