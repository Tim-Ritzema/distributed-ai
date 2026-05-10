# Client Registration

## Purpose

Define the full lifecycle of a client/device joining and leaving the system: pairing, identity, capabilities, sessions, and revocation. Phase 0 invariant — this exists from day one.

## Lifecycle

```
unprovisioned device
       ↓
   pairing request
       ↓
   admin approval (parent on a trusted client)
       ↓
   identity issued (long-lived keypair) + initial capabilities granted
       ↓
   device opens session (short-lived token derived from identity)
       ↓
   session active — publish/subscribe filtered by capability set
       ↓
   session expires — refresh requires device-key signature
       ↓
   device revoked (admin action) — all sessions terminate immediately
```

## Pairing

A new device cannot publish, subscribe, or query until it has been paired.

**Pairing flow:**

1. Device generates a long-lived keypair locally. The private key never leaves the device.
2. Device displays its public key fingerprint as a short code or QR (depending on form factor).
3. An admin (Tim or Laurie) opens a trusted client (a paired phone or laptop) and scans/enters the code.
4. Trusted client shows the admin: device kind, requested initial capabilities, owning principal.
5. Admin approves or denies. On approval, the Brain stores the public key, assigns the device an ID, and grants the initial capabilities.
6. Device receives confirmation and an initial session token.

**Out-of-band token fallback.** For devices without a screen (e.g., a headless Pi), the admin generates an enrollment token on a trusted client, copies it to the device's setup config, and the device presents it during pairing. The token is single-use and short-lived.

## Device identity

- **Long-lived public key.** Stored at pairing, never replaced silently. If a device's key needs rotation (compromise, hardware change), it goes through revocation + re-pairing.
- **Short-lived session tokens.** Derived from the identity key (signed challenge / refresh dance). Tokens have a TTL on the order of an hour; refresh requires a device-key signature.
- **No password authentication.** All client auth is keypair-based.

## Capability grants

Granted at pairing, modifiable later. A grant is a `(device_id, principal_id, capability)` triple, where capability is `{name, scope?}`.

Examples:

- `(bennetts-iphone, bennett, memory.read.private-personal[owner=bennett])` — Bennett's phone can read his own private memories.
- `(kitchen-pi-01, household, perception.publish[device=kitchen-pi-01])` — kitchen Pi may publish perception events for itself.
- `(kitchen-pi-01, household, presence.read[room=kitchen])` — kitchen Pi may subscribe to room-kitchen presence updates.
- `(laurie-laptop, laurie, capability.grant)` — Laurie's laptop, signed in as Laurie, may grant capabilities (admin action).

A grant is bound to a (device, principal) pair. The same device signed in as a different principal does not inherit the grant. A grant is revocable independently of the device identity.

## Topic subscription authorization

When a client opens a WebSocket (or MQTT, or any subscribe-capable transport) connection:

1. Server validates session token, resolves to (device, principal).
2. Client requests subscriptions to topics.
3. Server iterates subscribe requests; each topic has `subscribe_capability_required[]`.
4. Server filters to the subset the client's capability set covers (AND-semantics: all required capabilities must be present).
5. Server confirms the allowed subset; rejected subscriptions are reported back.
6. Each successful subscribe is audit-logged at low verbosity (full audit on denied attempts).

## Session expiry and rotation

- **Default TTL:** ~1 hour. Adjustable per device kind (a static install on the wall might have a longer-lived token; a phone might rotate frequently).
- **Refresh:** client signs a refresh challenge with its identity key; server verifies and issues a new token. No re-pairing required.
- **Idle disconnect:** a session with no activity for the TTL window expires automatically. Client must refresh on next request.

## Revocation

An admin can revoke a device. Effects:

- Device identity is marked revoked.
- All capability grants tied to that device are deactivated.
- All active sessions for that device terminate immediately. Any in-flight publish/subscribe operations fail.
- The Brain emits a `device.revoked` event on the realtime plane so other clients (e.g., Tim's phone) can update their UI.
- An audit log entry is written: who revoked, when, why (admin-supplied reason).

A revoked device cannot rejoin without going through full pairing again.

## Audit

Every grant, revoke, and pairing approval is audit-logged:

- `actor_principal_id` — the admin who took the action.
- `subject_principal_ids` — who the grant/revoke is about.
- `action` — `device.pair`, `capability.grant`, `capability.revoke`, `device.revoke`.
- `decision` — typically `allowed`, but denied attempts (e.g., a kid trying to grant a capability) are also logged.
- `reason` — free-form admin note where applicable.

Failed pairing attempts (admin denial, expired token) are also logged — useful for spotting probes or a misbehaving device.

## Design Invariants

- **No anonymous publish or subscribe.** Every event-bus connection has an authenticated principal and a known device.
- **Pairing requires an admin in the loop.** No self-service onboarding.
- **Identity keys never leave the device.** Loss of a device implies revocation + re-pairing on a new device.
- **Capability checks happen at every layer.** Pairing doesn't bypass them; admins still see the denial path.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — device identities, capability grants, and audit logs live in Postgres.

## Open Questions

- Pairing UX details. QR-based vs short-code vs TOFU-with-confirmation. Probably depends on form factor; deferred until Phase 1.
- Hardware-backed key storage (Secure Enclave, TPM). Nice-to-have; not Phase 0.
- Multi-admin approval for sensitive grants. Today a single parent can grant any capability; might require both parents to grant `cloud.use` later.
