/// A small, deterministic PRNG (splitmix64) — not cryptographic, just
/// reproducible across separate runs given the same seed. Swift's `Hasher`
/// is deliberately randomized per process, so it can't be used for this:
/// the whole piece's evolution has to be replayable from a seed, the same
/// way its memory is a file it reloads (see the README).
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
