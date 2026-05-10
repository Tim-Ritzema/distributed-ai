# Principles

## Purpose

The seven architectural invariants every doc and future code must respect. When in doubt, return here.

## The invariants

### 1. Local by default, cloud by explicit exception

Family data does not leave owned infrastructure except through an explicit allowlist with auditability. Cloud risks include vendor retention, server-side logs, telemetry, human review, breach exposure, policy changes, and accidental prompt leakage. None of these are theoretical. The default for every new feature is local execution; cloud egress requires a deliberate carve-out documented in the [cloud egress policy](../01-architecture/ai-orchestration.md).

### 2. Every user-visible datum has owner, tier, provenance, access policy

Every record a person can see — memory, event, work item, audit entry — carries:
- An **owner principal**. Either a family member or the **Household** (the family-as-a-whole principal that owns family-shared, room-occupancy, and unknown-subject data).
- A **privacy tier** (`private-personal`, `family-shared`, `room-safe`, `public-ambient`).
- A **provenance** record: source event, originating `source_type` + `source_id` (which may be a device, workflow, scheduler, agent, brain, or system), capability under which it was captured.
- An **access policy** derived from owner + tier + capability set.

If a piece of data does not have all four, it does not get stored.

### 3. Every client/device acts under a registered identity and a bounded capability set

No client connects anonymously. Pairing produces a long-lived device identity; sessions are short-lived tokens derived from it. Capability grants are bound to a (device, principal) pair, scoped to specific actions and data classes, and revocable. Sessions expire and rotate.

### 4. Every event carries authorization semantics for both publish and subscribe

The event envelope has separate `publish_capability_required[]` and `subscribe_capability_required[]` lists. The broker enforces each at the corresponding boundary. A client lacking the right capability cannot publish to nor subscribe from a topic — and the audit log records the decision.

### 5. Postgres is the source of truth for durable app state

See [ADR-0007](../05-decisions/0007-persistent-state-postgres.md). Every other data store is either a cache, a derived index, or an event log; Postgres holds the truth.

### 6. Decisions are captured in ADRs, not assumed in architecture docs

Architecture docs describe shape, contracts, and invariants. Specific technology picks (event broker, vector store, control-plane language, etc.) live in [05-decisions/](../05-decisions/) as ADRs. If a doc reads as if a tech choice has been made when no ADR backs it, the doc is wrong.

### 7. Goals/constraints, not microcommands

Higher layers issue intent; lower layers retain autonomy within their constraints. This is the [HDTS](../01-architecture/brain-to-nerve.md) principle, applied even at the day-one L4-only configuration. The brain says "greet Tim if he's alone in the kitchen"; the static install decides framing, timing, and tone.
