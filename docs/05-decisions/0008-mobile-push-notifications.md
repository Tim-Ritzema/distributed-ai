# ADR-0008: Mobile push notifications

**Status:** 🔵 open (Phase 3 concern)

## Context

Foreground mobile clients receive live updates over WebSocket. Backgrounded or closed mobile clients still need to receive proactive notifications — a job finished, a security alert, a family member needs attention. WebSockets don't survive backgrounding on iOS or aggressive Android battery management; some form of platform push is required.

Push is **complementary** to WebSockets, not a replacement. The pattern: push wakes the app → app reconnects WebSocket → live stream resumes ([01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md)).

This ADR isn't urgent — Phase 3 ([04-roadmap/phases.md](../04-roadmap/phases.md)) is when the mobile app ships. Tracking now so it doesn't get lost.

## Options

### Option A — APNS direct (iOS) + FCM direct (Android)

Talk to Apple's and Google's push services directly, no third-party.

- **Pros:**
  - No third-party intermediary handling our notifications.
  - Lowest possible data-sharing footprint.
  - Direct line to platform reliability.
- **Cons:**
  - Two integrations (APNS + FCM) to build and maintain.
  - Certificate / key management for both.
  - More custom code.

### Option B — Firebase Cloud Messaging (FCM) for both platforms

FCM supports both iOS (via APNS forwarding) and Android. One integration.

- **Pros:**
  - Single integration covers both platforms.
  - Mature, well-documented.
- **Cons:**
  - **Notification metadata routes through Google.** Even if the payload is generic ("you have an update"), the routing reveals patterns about device usage to Google.
  - Conflicts with the spirit of the [cloud egress policy](../01-architecture/ai-orchestration.md) — even though notification *content* is non-sensitive, the routing data is itself a privacy concern.

### Option C — OneSignal or similar third-party push service

- **Pros:**
  - Easy integration; many features (segmentation, scheduling, A/B).
- **Cons:**
  - More data-sharing than FCM (a third-party processor in the loop).
  - Cost for a feature set we don't need.
  - Even worse alignment with privacy goals than FCM.

### Option D — Self-hosted webpush (PWA)

If the mobile app is a PWA, the W3C Push API can deliver notifications via the user's browser push service (which routes through Apple/Google for iOS/Android Chrome respectively, but with end-to-end encryption of payloads).

- **Pros:**
  - Payload is encrypted; routing services don't see content.
  - No third-party SDK in the app.
  - Cross-platform via standard web APIs.
- **Cons:**
  - PWA on iOS still has push limitations historically; check current state when this becomes urgent.
  - Routing metadata still visible to platform push services (same as A/B).

## Decision

**Open.** No urgency until Phase 3.

Provisional lean: a hybrid — APNS direct for iOS native, webpush for PWA paths. Avoid FCM and OneSignal due to privacy footprint.

## Consequences

The choice affects:

- The mobile app's permission flow.
- What metadata about family activity (timing, device, frequency) leaks to platform push services.
- Notification payload format.
- Operational complexity (cert rotation for APNS, etc.).

Whatever the choice, **notification payloads must be generic.** "You have a new update" — never "Tim's doctor called." Sensitive content stays inside the app, fetched after the user opens it.

## References

- [01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md) — three transport categories including mobile push.
- [04-roadmap/phases.md](../04-roadmap/phases.md) — Phase 3 closes this.
- [00-orientation/principles.md](../00-orientation/principles.md) — local-by-default applies even to notification metadata.
