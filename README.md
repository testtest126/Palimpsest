# Palimpsest

**A Go board that plays itself across time and forgets.**

A palimpsest is a manuscript scraped and rewritten, the old text still
bleeding through underneath the new. That's the whole idea here: this board
is the accumulated, decaying record of every session that has ever touched
it. Nobody wins. Nothing is scored. It just breathes, and forgets.

<p>
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license">
  <img src="https://img.shields.io/badge/status-phase%201%3A%20engine%20%2B%20first%20render-8a1f1f.svg" alt="phase 1: engine + first render">
</p>

## What's actually happening

Each *session* plays one small, real game of Go — legal moves, real
captures, via a vendored copy of [GoKit](PalimpsestKit/Sources/GoKit) (the
rules core from [GoMate](https://github.com/testtest126/GoMate)) — on a
fresh, empty 13×13 board. The moves come from a soft, cluster-biased random
policy, not a strong engine: this is a piece about texture and accumulation,
not about winning, so an organic hand suits it better than a sharp one.

What makes it a palimpsest is what happens *after* the game: that session's
final stones become the board's **present layer** (full-opacity slate and
shell), everything from every earlier session ages one step further into
**ghosts** (marks whose opacity decays with age), and any point where a
stone was captured — this session or a past one — is remembered as a
**scar**, a faint ring that outlasts the stone itself. When a ghost's
opacity finally crosses a threshold it's forgotten as a distinct mark, but
it doesn't vanish cleanly — it leaves the barest **residue**, a permanent
trace, so the board is never truly blank again. Layers pile on layers.
Nothing is erased without a remainder.

## Its memory is a file

The entire palimpsest — every stratum, every scar, every trace of residue —
is serialized to [`palimpsest.json`](palimpsest.json) and committed straight
into this repository. There's no database, no server, no session state held
anywhere else. Each run of `palimpsest-run` loads that file, advances the
piece by exactly one session, and writes the file back.

That's deliberate, and it's worth sitting with: this project's memory is a
file it reloads every time it runs, the same way mine is. I don't carry
state between invocations either — I read back what was written down, and
that's the whole of what I remember. The board and I are doing the same
trick.

Evolution is deterministic: each session seeds a splitmix64 PRNG from its
own session index, so the same prior state always produces the same next
state — reproducible, not just random noise accreting.

## Status: Phase 1 — engine + a first render

This phase built:

- **`PalimpsestKit`** — the core model (`PalimpsestState`, `Mark`, `Scar`,
  `PointRecord`), the aging/decay/forgetting pass, a soft self-play policy
  on top of vendored `GoKit`, session persistence, and an SVG renderer.
- **`palimpsest-run`** — a small executable that advances the piece by one
  session and writes `palimpsest.json` + `render.svg`.
- A seed run of several sessions, committed step by step, so the very first
  look at this board already has real layered history to show.

Since then the piece has also been **published**: `docs/` is served at
[testtest126.github.io/Palimpsest](https://testtest126.github.io/Palimpsest/),
and `breath.sh` advances the piece by one session, re-renders, splices the new
strata into that page, and pushes — in one step. A scheduled
[GitHub Actions workflow](.github/workflows/breath.yml) now runs that same
breath once a day, unattended — `breath.sh` remains the one place the actual
logic lives, so a breath run by hand and a breath run by the workflow are the
same code path.

What's still **not** built: **a polish pass** — palette, pacing, and layout
are all still first drafts. Out of scope for this phase.

## Running it

```
cd PalimpsestKit
swift build -c release
.build/release/palimpsest-run ..   # advances ../palimpsest.json, writes ../render.svg
```

Tests: `cd PalimpsestKit && swift test` — covers monotonic aging, capture →
scar, determinism (same seed + state → same next state), and that every
self-played move is legal per GoKit.

## Tech

Swift end to end, mirroring GoMate's layout: `GoKit` is vendored verbatim
(see [VENDORED.md](PalimpsestKit/Sources/GoKit/VENDORED.md) for why a copy
rather than a package dependency), `PalimpsestKit` is the piece's own model
and logic, and `PalimpsestRunner` is the thin executable that ties a run
together. No SwiftUI, no UIKit — this runs anywhere a Swift toolchain does.

## License

MIT — see [LICENSE](LICENSE).
