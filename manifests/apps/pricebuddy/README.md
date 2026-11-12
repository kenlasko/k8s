# Summary
[PriceBuddy](https://github.com/jez500/pricebuddy) is a self-hosted price tracker. It watches product pages across stores, keeps a price history and sends notifications when prices drop. It is available at https://pricebuddy.laskonet.com.

It runs as two workloads, both deployed with my [custom Helm chart](/helm/baseline):
- `pricebuddy`: the app itself (Apache, plus the built-in cron scheduler and queue worker under supervisord)
- `pricebuddy-scraper`: a [SeleniumBase scraper](https://github.com/jez500/seleniumbase-scrapper) with headless Chrome, used for stores that block plain HTTP scraping. It is internal only, and a [CiliumNetworkPolicy](base/networkpolicy.yaml) restricts ingress to the PriceBuddy pod, because its API is unauthenticated and will fetch any URL.

It requires [PostgreSQL](/manifests/database/cnpg) to run.

Stateful data (`/app/storage`) is stored on the NAS via NFS at `/appdata/vol/pricebuddy` and backed up nightly to Cloudflare S3 storage via [Volsync](/manifests/system/volsync).

## Secrets
The image's start script runs `printenv`, so secrets are not passed as environment variables. They are rendered by External Secrets into a `.env` file mounted at `/app/.env`. A non-empty `.env` also stops the start script from generating a new `APP_KEY` on every restart.

Akeyless entries:
| Path | Properties |
|:-----|:-----------|
| `/pricebuddy` | `APP_KEY` (`base64:` + 32 random bytes, e.g. `echo "base64:$(openssl rand -base64 32)"`), `APP_USER_EMAIL`, `APP_USER_PASSWORD` (initial admin account, only used when seeding the database) |
| `/database/pricebuddy` | `username`, `password` |

Values must not contain a single quote (`'`).
