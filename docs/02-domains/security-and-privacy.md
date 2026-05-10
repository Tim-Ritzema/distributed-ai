# Security and Privacy

## Purpose

Define privacy tiers, the access decision model, the cloud-egress policy, and the rules around biometric and ambient data. This is where the "rash problem" lives.

## The rash problem

A static install in the kitchen identifies Tim walking past. It would be wrong for the install to greet him with "Hey Tim, how's the rash?" — even if the system has that memory and the install has identified him correctly. Other family members or guests may be in earshot. **Identification does not imply authorization to surface.**

The rash problem is the canonical example. It generalizes to: ambient devices must not reveal sensitive information about an identified person just because the identification succeeded. The privacy tier system below is how this rule is enforced uniformly.

## Privacy tiers

Every event, memory, and presentable datum carries one of four tiers:

| Tier | Visible to | Surface-able by ambient devices? |
|---|---|---|
| `private-personal` | owning family member only | no |
| `family-shared` | family on personal clients | no |
| `room-safe` | family on personal clients + static devices when room composition allows | yes (with checks) |
| `public-ambient` | anyone in earshot | yes |

Tiers go from most restrictive (`private-personal`) to least (`public-ambient`). The phrase "or less sensitive" means moving rightward in this list.

### Tier semantics

- **`private-personal`** — health, finances, school grades, romantic/relationship content, biometric data, any content the owner has explicitly marked private. Never surfaces on ambient devices. Never egresses to cloud without per-event approval.
- **`family-shared`** — content visible across the family but not appropriate for casual ambient surfacing. Calendar entries, household plans, kid school logistics. Personal clients show it; static installs do not speak it aloud.
- **`room-safe`** — content the owner is OK having spoken aloud when the room composition is known. "Tim is in the kitchen" is room-safe; "Tim has a doctor's appointment Tuesday" is family-shared, not room-safe.
- **`public-ambient`** — content fine for anyone in earshot. Generic greetings, weather, time. The fallback when room composition is unknown or mixed.

## Access decisions

An access decision is computed from six inputs:

1. **Owner** — who owns the data.
2. **Subject** — who the data is about (may equal owner, may not).
3. **Privacy tier** — `private-personal` through `public-ambient`.
4. **Client capability set** — what the requesting client has been granted.
5. **Room context** — who's currently in the room (for ambient devices).
6. **Presentation mode** — personal (a phone in someone's hand) vs ambient (a static install in a shared space).

Decisions are computed at the Brain (the source of truth) and at the broker (capability-gated topics). Defense-in-depth: a handler that forgets the check is a bug, not the only line of defense.

Every cross-tier or cross-principal access is **audit-logged**, allowed or denied.

## Capabilities gate API actions and event topics

Capabilities apply uniformly to:

- **API actions.** `POST /memories?owner=tim` requires `memory.write[owner=tim]`.
- **Event topic publish.** A device publishing on a topic must hold the `publish_capability_required[]`.
- **Event topic subscribe.** A consumer subscribing to a topic must hold the `subscribe_capability_required[]`.

Same vocabulary, same enforcement, same audit trail across both.

## Biometric and video privacy

Face embeddings, voice prints, raw camera frames, and audio snippets are **sensitive by default** — `private-personal` tier and tightly capability-gated.

**Static installs preferably emit derived facts, not raw data.** A Pi with a camera should publish `perception.face.seen` (a derived fact about a recognized person) rather than the underlying camera frame. Raw frames may be retained for very short windows (target: minutes) for downstream features that explicitly need them, gated by capabilities like `perception.read.raw[device=kitchen-pi-01]` that are granted only to specific worker processes.

This is also a defense against camera compromise: if a Pi is owned, the leaked data is mostly already-public room facts, not full video archives.

See [perception-and-presence.md](perception-and-presence.md) for the raw-vs-derived split in detail.

## Cloud egress policy

(Cross-references [ai-orchestration.md](../01-architecture/ai-orchestration.md), where the policy is fully laid out.)

Highlights:

- **Default: local.** Cloud reachable only via explicit allowlist, scoped per data class and per provider.
- Risks include vendor retention, server-side logs, telemetry, human review, breach exposure, policy changes, and accidental prompt leakage.
- Required when egressing: redaction rules, per-class consent verification, audit log entry per call.
- Sensitive classes (health, finances, school, romantic, biometric) **never** egress without per-event explicit user approval.

The egress policy is one specific application of the privacy-tier and capability model — cloud egress is just another capability gate (`cloud.use[provider=anthropic, class=general]`).

## Audit log requirement

Any of the following actions writes an AuditLog entry:

- Capability grant or revoke.
- Cross-principal read (parent reading kid data, etc.).
- Cross-tier escalation (loosening a memory's privacy tier).
- Cloud egress.
- Denied access attempt.
- Static-install presentation decisions that involved tier checks.

Audit log entries are owned by `household` and retained indefinitely.

## Design Invariants

- **No identification without authorization check.** Recognizing a person never triggers presentation; the capability and tier checks happen between recognition and speaking.
- **Tier is metadata that travels with data.** Memories inherit tier from their producing events. Aggregations inherit the most restrictive tier of their components by default.
- **Defense-in-depth.** Capability checks happen at the Brain, the broker, and the storage layer. Forgetting one is a bug; relying on only one is the wrong design.
- **Deny without leak.** When access is denied, the response does not confirm the existence of the underlying data.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — audit log lives in Postgres.

## Open Questions

- Per-class consent UX. How does Tim grant or revoke "cloud-allowed for general work"? Probably an admin action on a trusted client, audit-logged.
- Static-install behavior when the camera is degraded (blurry, dark, occluded). For now: drop to `public-ambient` automatically.
