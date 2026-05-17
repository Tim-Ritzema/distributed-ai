# Deployment 🟡

## Repo Boundary

`distributed-ai` owns the application: Brain, workers, clients, prototypes, docs, and app-level deployment assets.

`local-computer-control` owns the fleet control layer: host inventory, SSH credentials, key bootstrap, OS/package setup, system services, and repeatable scripts for preparing machines to run the app.

Put another way: `distributed-ai` defines what runs; `local-computer-control` prepares where it runs.

## Current Prototype

The Wubblefazz avatar/perception prototype now lives at `prototypes/avatar-lab/`. It includes the static browser client and the S3/CloudFront deployment script for `home.wubblefazz.com`.

The Pi kiosk setup remains in `local-computer-control` because it configures a physical host to open that deployed URL.

## Current Database Host

`mac-mini-1` is the day-one database host for Postgres and pgvector. Fleet identity and hardware details live in `/Users/timrossi/Desktop/CODE/local-computer-control/inventory.yaml`:

- Host: `mac-mini-1` / `mac-mini-m1` on the home LAN.
- Hardware: Macmini9,1; Apple M1 (8 cores); 16 GB unified memory; 512 GB Apple SSD.
- Runtime: PostgreSQL `18.4 (Homebrew)` via Homebrew `postgresql@18`.
- Extension: pgvector `0.8.2`.

`local-computer-control` owns machine preparation, package installation, launchd service setup, firewall/power settings, and secrets. The relevant provisioning script is `/Users/timrossi/Desktop/CODE/local-computer-control/scripts/device/mac-mini-1/install-postgres.sh`.

`distributed-ai` owns schema design, migrations, application-level database access, and backup/restore expectations for this app.

## Secrets

AWS credentials for the prototype deploy live in `distributed-ai/.env`, which is gitignored. `distributed-ai/.env.example` documents the expected variable names.

Remaining service definitions, network setup, and broker topology will firm up after [ADR-0002](../05-decisions/0002-event-broker.md) closes.
