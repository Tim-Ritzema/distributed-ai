# ADR-0009: Worker fleet topology

**Status:** 🟢 accepted (three-host split: DB on `mac-mini-1`, Brain on `mac-mini-2`, FastAPI worker service + AI model runtimes on Mac Studio; workflow-engine placement deferred to ADR-0006)

## Context

[ADR-0001](0001-control-plane-language.md) accepted a hybrid Elixir/Phoenix Brain + Python AI workers, and stated that workers communicate with the Brain "over HTTP and whichever event boundary [ADR-0002](0002-event-broker.md) accepts." It did not specify *where* each runtime lives or *how* the Brain selects a worker URL. [ADR-0007](0007-persistent-state-postgres.md) pegged Postgres + pgvector to `mac-mini-1`. The original [physical-topology.md](../01-architecture/physical-topology.md) treated worker-split as a Phase 1+ migration triggered by throughput pressure on the Brain.

The terms "Brain" and "Python AI worker" must be kept distinct:

- The **Brain** owns the control plane *and* the **agent runtime** — the event, idle, and maintenance loops described in [01-architecture/system-overview.md](../01-architecture/system-overview.md) and [00-orientation/glossary.md](../00-orientation/glossary.md). These are supervised processes that orchestrate, decide, and route. They are Elixir/OTP, not Python.
- The **Python AI worker tier** covers everything from synchronous model inference (transcription, embeddings, vision, OCR, LLM calls via Ollama) to longer-running multi-step Python work — research jobs, coding agents, scheduled analysis — per [02-domains/background-processing.md](../02-domains/background-processing.md). Workers are called by the Brain via sync HTTP for synchronous tasks, and may consume from / emit to the event plane for asynchronous work (their established role per [system-overview.md](../01-architecture/system-overview.md)). They do not host the agent runtime loops.

**ADR-0009 pins the synchronous-inference half of the Python worker tier to the Studio.** Where the workflow engine and its workers eventually live is [ADR-0006](0006-workflow-engine.md)'s call. The Studio is the likely host for workflow workers if ADR-0006 places them in the worker tier, but ADR-0009 does not pin that.

Three things have changed since the original topology was written:

- A second Mac mini is available on the household LAN. The split no longer requires new hardware.
- The reliability cost of co-locating Brain and the worker tier is now considered to outweigh the operational cost of a second host. Ollama model swaps, GPU pressure, and Python worker faults should not be able to drop client channels or stall event ingestion.
- The Pre-Phase 0 spike and Phase 0 are imminent. The topology used in the spike is the topology Phase 0 inherits; locking it down now avoids rework.

The synchronous dispatch path (Brain → worker for a single task, response expected) is the focus here. Async / multi-step workflows remain the concern of [ADR-0006](0006-workflow-engine.md). The durable broker boundary remains the concern of [ADR-0002](0002-event-broker.md).

## Options

### Option A — Single host (status quo from original `physical-topology.md`)

Brain (Phoenix + agent runtime), FastAPI workers, and Ollama all on Mac Studio. Postgres on `mac-mini-1`.

- **Pros:**
  - Simpler topology, one process tree, no LAN hop on worker calls.
- **Cons:**
  - GPU/Ollama workloads can starve the agent runtime under load.
  - Reboot or model swap on Studio takes channels, sessions, and event ingestion down.
  - Reliability of an "always-on" Brain is coupled to GPU-bound Python workloads.

### Option B — Three-host split by tier *(selected)*

- `mac-mini-1` — Postgres + pgvector.
- `mac-mini-2` — Phoenix Brain (control plane + agent runtime).
- Mac Studio — FastAPI worker service + Ollama + AI model runtimes. Likely host for Python workflow workers if [ADR-0006](0006-workflow-engine.md) places them in the worker tier, but that placement is not decided here.

The Brain dispatches synchronous tasks via HTTP over the LAN to the Studio. Endpoints are task-kind-shaped (e.g., `POST /transcribe`, `POST /embed`, `POST /chat`, `POST /vision`). A hardcoded `task_kind → host_url` map inside the Brain selects the target host.

- **Pros:**
  - Control plane + agent runtime decoupled from worker-tier workload. Studio reboots / model swaps / OOMs do not drop client sessions or break the event loop.
  - Hardware roles match form factors: mini as always-on appliance, Studio as GPU/inference box.
  - Failure isolation: degraded UX is "the AI is thinking…" rather than "the system is down."
  - Postgres stays on a host that runs no third-party code.
- **Cons:**
  - One additional host to deploy and operate.
  - Every worker call is a cross-host HTTP hop. In-LAN this is 1–3 ms — negligible against the AI work itself.

### Option C — Three-host split by weight

- `mac-mini-1` — Postgres.
- `mac-mini-2` — Phoenix Brain **and** light/medium AI workers (small Whisper, small embeddings, VAD, OCR, classifiers, face landmarking).
- Mac Studio — heavy AI workers (Ollama, large Whisper, large embeddings, larger vision models).

- **Pros:**
  - Maximises AI throughput across boxes.
- **Cons:**
  - Brain shares a host with worker processes — weaker failure isolation than Option B.
  - Routing logic must be weight-aware on top of task-kind-aware.
  - The household-scale workload is mostly serial; throughput gain is largely theoretical.

### Option D — Defer to a workflow engine

Let [ADR-0006](0006-workflow-engine.md) handle dispatch and placement declaratively.

- **Pros:**
  - Declarative routing, scales if usage grows.
- **Cons:**
  - Conflates async workflow orchestration with sync request/response dispatch.
  - Heavy for "transcribe this 3-second clip."
  - Forces ADR-0006 to close before Phase 0 can ship, which it isn't ready to do.

## Decision

**Option B — three-host split by tier, on day one.**

- **`mac-mini-1`** — Postgres + pgvector (unchanged from ADR-0007).
- **`mac-mini-2`** — Phoenix Brain. Control plane and the full agent runtime (event, idle, maintenance loops per [system-overview.md](../01-architecture/system-overview.md)). Sync task dispatch, durable event log writers, identity/capability gates.
- **Mac Studio, garage** — FastAPI worker service + Ollama + AI model runtimes (sync HTTP dispatch endpoints). **No agent-runtime loops, no client channels.** Workers may still consume from / emit to the event plane as [ADR-0002](0002-event-broker.md) and [background-processing.md](../02-domains/background-processing.md) describe — that's their established role and is out of this ADR's scope to change. **Workflow engine and workflow workers are not placed by this ADR**; the Studio is the likely host if [ADR-0006](0006-workflow-engine.md) puts them in the worker tier, but that decision lives there.

### Dispatch convention

- Synchronous tasks are dispatched from the Brain to the Studio over HTTP.
- The Brain holds a hardcoded `task_kind → worker_host_url` map. No service discovery, load balancing, or health-check failover in Phase 0.
- Endpoints are task-kind-shaped (transcribe, embed, chat, vision, OCR, …). The exact endpoint set is an implementation detail; this ADR records the pattern only.

### Service-to-service auth

Worker access control is **defense-in-depth**: network exposure narrowed by interface bind and firewall, authentication enforced by a shared bearer token. The bearer token is the actual gate; the network controls are belt-and-suspenders.

- **Interface bind.** Studio FastAPI binds to the Studio's LAN interface, **not the WAN/public interface**. This prevents external exposure; it does **not** by itself filter on-LAN traffic.
- **Firewall allowlist.** Host firewall (or equivalent network policy owned by `local-computer-control`) restricts the worker port's inbound source to `mac-mini-2`'s LAN IP. A misbehaving LAN device — visitor laptop, IoT device — cannot reach the port at all.
- **Bearer token.** Every request from the Brain carries `Authorization: Bearer <token>`. Workers reject any request missing or failing the token check. This is the actual auth mechanism.
- **Provisioning.** The token is provisioned out-of-band via env vars on both Brain and Studio. `local-computer-control` owns provisioning; `distributed-ai` owns the verification logic.
- **TLS.** Not required in Phase 0. The bearer token travels in cleartext over the LAN, which assumes the LAN is trusted at the confidentiality layer (no hostile sniffing devices reaching the Brain↔Studio path). If that assumption breaks, switch to TLS (and consider mTLS).
- **Deferred.** mTLS, per-task tokens, and rotation policies are deferred. Triggers: (a) a remote worker host is added; (b) any worker traffic crosses an untrusted network; (c) the LAN's confidentiality assumption stops holding (e.g., guest segments).

This honors [physical-topology.md](../01-architecture/physical-topology.md)'s "no untrusted ingress" and "every connection authenticates" stance without overbuilding for Phase 0.

## Consequences

- [`01-architecture/physical-topology.md`](../01-architecture/physical-topology.md) hardware-roles table rewrites the Brain row to `mac-mini-2` and adds a "Python AI workers" row for the Studio. The "Migration paths" intro sentence and AI-worker-split item are updated.
- [`04-roadmap/phases.md`](../04-roadmap/phases.md) Phase 0 scope changes Brain to `mac-mini-2` and points the sync FastAPI worker service + AI model runtimes at the Studio. Workflow-worker placement is left to ADR-0006. The Pre-Phase 0 spike adds a Brain → worker sync HTTP call to balance the existing worker → Brain call, validating both directions of ADR-0009.
- [`01-architecture/system-overview.md`](../01-architecture/system-overview.md) — Known Decisions section gains this ADR. No component-diagram change: the Brain box already includes "control plane · agent runtime · event router · auth," which is exactly the role on `mac-mini-2`.
- [`00-orientation/overview.md`](../00-orientation/overview.md), [`00-orientation/glossary.md`](../00-orientation/glossary.md), [`01-architecture/brain-to-nerve.md`](../01-architecture/brain-to-nerve.md), [`docs/README.md`](../README.md), and [`04-roadmap/open-questions.md`](../04-roadmap/open-questions.md) update wording to reflect the host split.
- [`03-operations/deployment.md`](../03-operations/deployment.md) gains "Current Brain Host" (`mac-mini-2`) and "Current Worker Host" (Mac Studio) sections, plus the defense-in-depth auth rule (interface bind, firewall allowlist, bearer token, plus the cleartext-LAN caveat and deferred triggers).
- [ADR-0001](0001-control-plane-language.md) is unchanged at the contract level — language choice and worker boundary stay accepted. This ADR fills in host placement and dispatch convention only.
- [ADR-0002](0002-event-broker.md) is bounded against this ADR rather than unaffected: **sync HTTP dispatch from the Brain to a named worker host is this ADR's territory**; **broker-backed work queues with replay, redelivery, or multi-consumer fanout across machines remain ADR-0002's territory.** ADR-0002 named "cross-machine worker distribution" as a NATS trigger; that still holds for distributed *queues*. Single-target sync RPC over HTTP is not what triggers the broker conversation.
- [ADR-0006](0006-workflow-engine.md) — async / multi-step orchestration is out of scope here. **Neither the workflow engine nor its workers are placed by this ADR.** ADR-0006's existing "runs comfortably alongside the Brain" wording predates this ADR's Brain/worker host split; it is being trimmed and replaced with a Consequences bullet in ADR-0006 noting that placement is not decided until ADR-0006 closes.
- Latency: in-LAN HTTP between `mac-mini-2` and Studio costs roughly 1–3 ms per call.
- Reboot story improves: Studio reboots drop in-flight inference calls but leave channels, event ingestion, identity/capability checks, and the agent runtime alive on `mac-mini-2`.

## References

- [ADR-0001](0001-control-plane-language.md) — control plane language; this ADR specifies host placement and sync dispatch.
- [ADR-0002](0002-event-broker.md) — broker boundary; explicitly bounded against this ADR's sync-HTTP dispatch scope.
- [ADR-0006](0006-workflow-engine.md) — async orchestration; out of scope here. Workflow-engine and workflow-worker placement remain ADR-0006's call. Updated by this ADR for host-placement wording.
- [ADR-0007](0007-persistent-state-postgres.md) — Postgres on `mac-mini-1`; unchanged.
- [01-architecture/physical-topology.md](../01-architecture/physical-topology.md) — hardware table and migration paths updated by this decision.
- [01-architecture/system-overview.md](../01-architecture/system-overview.md) — agent runtime lives on the Brain (this ADR does not move it).
- [00-orientation/glossary.md](../00-orientation/glossary.md) — Brain definition updated to point at `mac-mini-2`.
- [02-domains/background-processing.md](../02-domains/background-processing.md) — workflow workers consume from and emit to the event plane; this ADR does not change that, and does not place them.
- [04-roadmap/phases.md](../04-roadmap/phases.md) — Phase 0 scope and Pre-Phase 0 spike updated.
- [03-operations/deployment.md](../03-operations/deployment.md) — Current Brain Host and Current Worker Host sections, including service-to-service auth.
