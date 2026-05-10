# Brain to Nerve (HDTS)

## Purpose

Capture the **HDTS** (Hierarchical Delegation with Temporal Stratification) concept from mia-sempre as an architectural influence — not a day-one implementation requirement. The principle informs how the brain talks to lower layers, even when only one layer exists today.

## The hierarchy

A biologically-inspired four-layer model bridging consciousness (seconds) to motor control (microseconds):

```
L4 (Consciousness):    Brain · agent runtime          ~1–5  seconds
                            ↓ goals + constraints (~1 Hz)
L3 (Motor planning):   Device-local planning          ~10–50 ms
                            ↓ primitives (~20–100 Hz)
L2 (Skill execution):  On-device skills               ~1–5  ms
                            ↓ commands (~1 kHz)
L1 (Reflexes):         Hard-real-time reflexes        ~10–100 μs
```

For this project, the layers map approximately to:

- **L4** — Brain on the Mac Studio. Reasoning, planning, conversation, autonomous task execution. Operates at human-second timescale.
- **L3** — Device-local planning on capable clients. Mobile app turn coordination, avatar response timing, multi-step UI flows. Mostly absent day-one.
- **L2** — Thin per-device skills. Pi face detection, wake-word recognition, gesture detection, camera framing. Day-one Pis run only this.
- **L1** — Hard-real-time reflexes (camera framing servos, mute toggles, robot motor control). **Not in scope** until there's physical embodiment.

## Day-one scope

**Day-one is L4 only,** with thin L2 on Pis when they exist. L3 and L1 are deferred.

What this means concretely:

- The Brain reasons; Pis report observations and follow simple commands.
- There is no intermediate planning layer between the Brain and a Pi today. A Pi running face detection emits events; the Brain decides what happens.
- A static install rendering an avatar follows brain-issued state, but the brain does not micromanage frame timing or animation curves.

## The principle that survives even at L4-only

**Higher layers issue goals and constraints, not microcommands.**

This shows up even within the day-one configuration:

- The Brain says "greet Tim if he's alone in the kitchen and the room is room-safe." It does not say "render `Hello, Tim` in 24pt Inter at 700ms after detection."
- A workflow run says "transcribe this audio with high quality." It does not say "use whisper-large-v3 with these specific decoding parameters."
- A Pi running face detection reports `perception.face.seen` with confidence and bounding box. It does not stream raw frames "just in case."

This discipline is what makes future HDTS expansion tractable. When L3 (device planning) is added, the Brain doesn't need to change — it was already issuing intent rather than commands.

## When HDTS gets real

The roadmap ([phases.md](../04-roadmap/phases.md)) parks full HDTS at **Phase 5**, contingent on physical embodiment becoming a goal. Triggers that would advance it:

- A robot or actuated device entering the system (farmbot, household helper).
- A Pi-class device with motor control (camera servos, avatar mechanics).
- Latency-critical interactions where round-tripping to the Brain becomes the bottleneck.

Until those happen, HDTS is documentation, not code.

## Design Invariants

- **Goals over microcommands.** Every API and event payload should look like intent, not micro-state.
- **Local autonomy within constraints.** Lower layers may refuse, defer, or qualify a goal — they are not dumb pipes.
- **Temporal separation is real.** Code that mixes second-scale reasoning with millisecond-scale control will break. When such code appears, that's the trigger to introduce a new layer.

## Open Questions

- The exact L2/L3 split when we get there. Probably driven by which device is involved (a Pi with a camera vs a robot with motors).
- Whether L3 lives on the Brain ("planning is centralized") or on the device ("planning is local"). HDTS as written favors device-local; we can revisit when there's a concrete case.
