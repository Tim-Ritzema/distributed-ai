# Deployment 🟡

## Repo Boundary

`distributed-ai` owns the application: Brain, workers, clients, prototypes, docs, and app-level deployment assets.

`local-computer-control` owns the fleet control layer: host inventory, SSH credentials, key bootstrap, OS/package setup, system services, and repeatable scripts for preparing machines to run the app.

Put another way: `distributed-ai` defines what runs; `local-computer-control` prepares where it runs.

## Current Prototype

The Wubblefazz avatar/perception prototype now lives at `prototypes/avatar-lab/`. It includes the static browser client and the S3/CloudFront deployment script for `home.wubblefazz.com`.

The Pi kiosk setup remains in `local-computer-control` because it configures a physical host to open that deployed URL.

## Secrets

AWS credentials for the prototype deploy live in `distributed-ai/.env`, which is gitignored. `distributed-ai/.env.example` documents the expected variable names.

Service definitions, network setup, and full deployment topology will firm up after [ADR-0002](../05-decisions/0002-event-broker.md) closes.
