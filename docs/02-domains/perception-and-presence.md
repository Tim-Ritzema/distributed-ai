# Perception and Presence

## Purpose

Define the two-layer split between **raw observations** (camera frames, embeddings, audio) and **derived presence state** (who is where), and the privacy rules that follow.

## Two layers

### Raw observations

- **Examples:** camera frames, face embeddings, voice prints, audio snippets, depth-sensor reads.
- **Privacy tier:** `private-personal` by default, regardless of who's identified.
- **Retention:** strict, tier-driven defaults — minutes to hours unless a feature explicitly retains them. After the retention window, the data is hard-deleted, not soft-marked.
- **Access:** highly restricted. Generally subscribable only by the producing device and the Brain; specific worker processes can be granted `perception.read.raw[device=<device_id>]` for narrow purposes (e.g., a face-recognition trainer).
- **Topic separation.** Raw observations live on dedicated, capability-gated topics distinct from derived presence topics. A subscriber to `presence.changed` cannot see raw frames; a subscriber to `perception.raw` is a small, audited list.

### Derived presence state

- **Examples:** "Tim is in the kitchen", "unknown face in the living room", "kitchen has 2 people", "no one home for 4 hours".
- **Privacy tier:** typically `room-safe`, occasionally `family-shared` depending on the fact.
- **Owner:** a personal-presence fact (`tim is in kitchen`) is owned by Tim. A room-occupancy aggregate (`kitchen has 2 people`) is owned by `household`. An unknown-face observation is owned by `household`.
- **Access:** broader. This is what static installs, the SvelteKit dashboard, and other room-aware features should consume.

## The split rule

**Derived facts may be published to broader topics; raw data must not.** A static install should publish `perception.face.seen` (a derived fact about a recognized person) — not the underlying camera frame. A device that needs to publish raw frames must hold `perception.publish.raw[...]`, which is granted sparingly and audit-logged.

This is partly a privacy protection and partly a defense: if a Pi is compromised, the broader topic carries facts the household has already accepted, not high-resolution video.

## Group-aware degradation

Presence is the foundation for the rash-problem rules in [security-and-privacy.md](security-and-privacy.md). The mechanism:

1. The Brain maintains derived per-room presence: who's there, how confident, when last updated.
2. When a static install considers surfacing something, it checks the room's current composition.
3. **If more than one person is present, the room degrades to `public-ambient`** until alone again. The static install can still speak, but only generic content.
4. **If presence is uncertain** (low-confidence detection, multiple ambiguous faces, the camera is occluded), the room defaults to `public-ambient`.

The Brain emits `presence.degraded` and `presence.restored` events so static installs can pick up changes immediately rather than re-querying.

## Avatar visualization

A static install's avatar (animated face on the screen) is a **presentation concern of the static client**, not the Brain. The Brain emits avatar-state events (e.g., "looking attentive", "speaking", "confused") and the static client renders. The Brain does not micromanage frame timing — see the goals/constraints invariant in [00-orientation/principles.md](../00-orientation/principles.md).

## Worked example

Re-stating Flow 1 from [example-flows.md](../01-architecture/example-flows.md) in this doc's framing:

1. Kitchen Pi camera observes a face. On-device model recognizes Tim.
2. Pi publishes a **derived** event `perception.face.seen` with `subject=[tim]`, `room=kitchen`, `privacy_tier=room-safe`. The publish capability gate ensures only the kitchen Pi can publish this event for itself.
3. The raw camera frame, if retained, lands on `perception.raw[device=kitchen-pi-01]` with `privacy_tier=private-personal`. Almost no client subscribes to this; retention is short.
4. The Brain consumes `perception.face.seen`, updates room-kitchen presence, emits `presence.changed` and `room.occupancy.changed`.
5. The static install in the kitchen subscribed to `presence.changed[room=kitchen]` decides whether to greet, gated by group-aware degradation.

## Design Invariants

- **Default tier for raw biometric data is `private-personal`.** Even if a more permissive tier seems convenient, the default is restrictive.
- **Static installs prefer derived facts.** Publishing raw data requires a specific capability; receiving raw data requires another.
- **Retention is enforced, not aspirational.** A maintenance loop sweeps expired raw observations and audit-logs the deletion count.
- **Presence is derived state, not the truth.** The truth is the underlying observations. Presence may be stale, low-confidence, or wrong; consumers should treat it as the latest available approximation.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — presence state lives in Postgres; raw observations may live in Postgres or a side store depending on volume.

## Open Questions

- Exact retention windows by data type. Provisional defaults: face embeddings retained 30 days for known-face training; raw frames retained 1 hour by default; audio snippets retained 0 (transcribed and discarded). Refine in Phase 2.
- Multiple-camera disambiguation. If two Pis see overlapping rooms, how do we deduplicate presence? Probably room-id is the dedupe key. Decide when the second Pi enters the system.
- Confidence thresholds for "this is Tim" vs "I'm not sure." Defer until first Pi is on the wall.
