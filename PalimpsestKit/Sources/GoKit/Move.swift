/// A single turn: play a stone, or pass. There is no resign in Phase 1 — study
/// drills replay finished or in-progress positions, they don't need it.
public enum Move: Equatable, Sendable, Codable {
    case play(Point)
    case pass
}
