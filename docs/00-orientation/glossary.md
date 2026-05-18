# Glossary

Terms appear here once and are used consistently across all docs. When a doc introduces a new term, it goes here.

## Principals and identity

- **Principal** — an authenticated subject of the system. One of three kinds: **family member**, **Household**, or **ServicePrincipal**. Identified by lowercase stable IDs (`tim`, `laurie`, `bennett`, `drew`, `david`, `william`, `household`, `agent`, ...) — never display names.
- **Family member** — a human principal: Tim, Laurie, Bennett, Drew, David, or William. Has a **role** of `parent` or `kid`.
- **Household** — the singleton non-human principal that owns family-shared data, room-occupancy facts, and observations whose subject is unknown (e.g., `perception.face.unknown`).
- **ServicePrincipal** — a non-human principal that can hold capabilities and be assigned work, but cannot **own** data and cannot be an **actor** or **triggered_by**. The canonical service principal today is `agent` (the AI itself).
- **Role** — `parent` or `kid`. Drives default access rules. Parents may read kid-related data; kids may not read parent or sibling private data. Roles apply only to family members.

## Devices and clients

- **Client** — any process that connects to the system on behalf of a principal. Includes mobile apps, web portals, static installs, Pis, laptops.
- **Device** — physical hardware. A device may host one or more clients.
- **Static installation** — a wall-mounted device with a screen and camera, addressing whoever's in the room. Operates under a special role with limited capabilities even when it identifies a known person.
- **Brain** — the control plane / agent runtime. Initially runs on `mac-mini-2` on the home LAN. The FastAPI worker service + AI model runtimes live separately on the Mac Studio per [ADR-0009](../05-decisions/0009-worker-fleet-topology.md); workflow-worker placement is deferred to [ADR-0006](../05-decisions/0006-workflow-engine.md).
- **Body** — an embodiment of intent (a Pi avatar, mobile app, future robot). One mind, many bodies.

## Events

- **Event** — a structured message carrying observation, action, or state change. See [event-system.md](../01-architecture/event-system.md) for the envelope.
- **Actor** — the family-member principal who **performed the specific action** that produced this event. **Null** for events originated by system, device, scheduler, workflow, or agent — origin is then conveyed by `source_type` + `source_id`. There is no "system" principal value.
- **Triggered by** — the family-member principal who **initiated the chain** that led to this event, even if a non-human entity performed each step. A workflow Tim queued has `actor=null, triggered_by=tim`. Lets consumers route "events I started" without conflating with "events I performed."
- **Subject** — who the event is about. May or may not be the actor; may be empty (e.g., unknown face).
- **Owner** — whose data the event becomes once stored. May be a family member or `household` (never a ServicePrincipal).
- **Observer** — the device or process that witnessed/produced the event. Conveyed by `source_type` + `source_id`.
- **`source_type`** — enum: `device`, `brain`, `scheduler`, `workflow`, `agent`, `system`. Distinguishes physical devices from internal originators.
- **`source_id`** — identifier within the chosen `source_type` (a `device_id`, `workflow_run_id`, `agent_session_id`, etc.).

## Privacy and capabilities

- **Privacy tier** — one of `private-personal` (most restricted), `family-shared`, `room-safe`, `public-ambient` (least restricted). See [security-and-privacy.md](../02-domains/security-and-privacy.md).
- **Capability** — a structured grant: `{name, scope?}`. DSL form: `memory.read.private-personal[owner=tim]`. Scope keys are lowercase stable IDs. Capabilities are split into **publish-required** and **subscribe-required** at the topic level.
- **Capability grant** — bound to a (device, principal) pair, modifiable by an admin (parent), revocable.

## Domains

- **Work-item** — a Project, Feature, or Task. See [projects-and-backlog.md](../02-domains/projects-and-backlog.md).
- **Memory** — a stored fact with provenance, tier, and owner. See [memory-and-context.md](../02-domains/memory-and-context.md).
- **Presence** — derived state about who is where. Not the same as raw camera observations.

## System concepts

- **Control plane** — the always-on service that handles device sessions, event routing, and orchestration. Elixir/Phoenix per [ADR-0001](../05-decisions/0001-control-plane-language.md), with Python workers handling AI/ML tasks.
- **Plane** — one of five separated concerns: realtime event routing, durable event history, device telemetry, workflow orchestration, persistent app state. See [system-planes.md](../01-architecture/system-planes.md).
- **HDTS layer** — Hierarchical Delegation with Temporal Stratification. L4 (consciousness, ~seconds) → L1 (reflexes, ~microseconds). Day-one is L4 only. See [brain-to-nerve.md](../01-architecture/brain-to-nerve.md).
- **Agent runtime loops** — the brain runs three: an **event loop** (consume + dispatch), an **idle loop** (reflection / planning when no events demand attention), a **maintenance loop** (retention sweeps, cache warmup, capability re-checks).
