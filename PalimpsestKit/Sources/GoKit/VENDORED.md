# Vendored from GoMate

These four files (`Core.swift`, `Board.swift`, `Move.swift`, `Game.swift`) are
copied, unmodified, from
[testtest126/GoMate](https://github.com/testtest126/GoMate)'s `GoKit` package
— specifically its `GoKit/Sources/GoKit/` directory at commit `f313912`
(2026-07-31). MIT-licensed there and here.

**Why vendored, not a package dependency:** GoMate's `Package.swift` lives at
`GoMate/GoKit/Package.swift`, not the repo root, so it can't be added as a
standard Swift Package Manager git dependency without restructuring GoMate —
out of scope for this project. Vendoring keeps Palimpsest buildable from a
fresh clone with no sibling-repo assumptions.

**Not vendored:** `Scoring.swift` (area/territory scoring, komi) — Palimpsest
has no scoring, no winner, so it isn't needed. `GoProtocol` (the engine layer:
`GoEngine`, `RandomMover`, `GreedyEngine`, `MCTSEngine`) also isn't vendored;
Palimpsest's own soft self-play policy lives in `PalimpsestKit` instead — it
wants organic, not strong, play (see that module's docs).

If GoMate's rules core changes in a way worth pulling in here, that's a
manual re-copy of these four files, not an automatic update.
