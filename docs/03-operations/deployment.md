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

## Current Brain Host

`mac-mini-2` is the day-one host for the Phoenix Brain (control plane + agent runtime) per [ADR-0009](../05-decisions/0009-worker-fleet-topology.md). Hardware specifics and provisioning live in `local-computer-control`'s `inventory.yaml`; service installation, BEAM runtime, and launchd setup are owned there.

`distributed-ai` owns the Phoenix application source, configuration shape, schema migrations against `mac-mini-1`, and Channel / event-router code.

## Current Worker Host

The Mac Studio (garage) is the day-one host for the Python AI worker tier per [ADR-0009](../05-decisions/0009-worker-fleet-topology.md). It runs the FastAPI worker service, Ollama, and local model runtimes (transcription, embeddings, vision, OCR, LLM inference). Python workflow workers are the likely next addition here once [ADR-0006](../05-decisions/0006-workflow-engine.md) closes, but their placement is ADR-0006's decision — not ADR-0009's.

`local-computer-control` owns machine preparation, Python environment, model installation, and service supervision. `distributed-ai` owns the FastAPI application source, endpoint contracts, and the routing table the Brain uses to dispatch tasks.

Worker service auth follows the **defense-in-depth** rule defined in [ADR-0009](../05-decisions/0009-worker-fleet-topology.md): the Studio FastAPI binds to the LAN interface (not WAN), the host firewall allowlists `mac-mini-2`'s LAN IP as the only inbound source, and every request requires `Authorization: Bearer <token>` (the actual auth gate — interface bind and firewall are belt-and-suspenders, not access control). The bearer token is provisioned out-of-band via env vars (owned by `local-computer-control`); `distributed-ai` owns token verification.

TLS is not required in Phase 0. The token travels in cleartext over the LAN, which assumes the LAN is trusted at the confidentiality layer. mTLS, per-task tokens, and TLS itself are deferred until (a) a remote worker host is added, (b) worker traffic crosses an untrusted network, or (c) the LAN's confidentiality assumption stops holding (guest segments, etc.). See ADR-0009 for the canonical rationale and deferred-item triggers.

## Secrets

AWS credentials for the prototype deploy live in `distributed-ai/.env`, which is gitignored. `distributed-ai/.env.example` documents the expected variable names.

Remaining broker topology, plus any service definitions and network setup not already covered by [ADR-0009](../05-decisions/0009-worker-fleet-topology.md), will firm up after [ADR-0002](../05-decisions/0002-event-broker.md) closes.
