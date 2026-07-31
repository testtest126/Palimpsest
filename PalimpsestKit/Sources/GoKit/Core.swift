import Foundation

/// A single intersection on the board, using (0,0) as one corner.
public struct Point: Hashable, Sendable, Codable {
    public let x: Int
    public let y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
}

public enum Stone: String, Sendable, Codable, CaseIterable {
    case black, white

    public var opponent: Stone { self == .black ? .white : .black }
}

/// Board sizes used for real games and study. `Board` itself accepts any
/// positive size — small hand-authored boards are far more tractable to
/// write unit tests against than a full 9x9 or 19x19 — but these three are
/// what the app exposes to a player.
public enum StandardBoardSize: Int, CaseIterable, Sendable, Codable {
    case nine = 9
    case thirteen = 13
    case nineteen = 19
}
