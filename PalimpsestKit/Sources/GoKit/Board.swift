import Foundation

/// An immutable snapshot of stones on a square grid. `Board` has no notion of
/// whose turn it is or how it got here — that's `Game`'s job. Two boards with
/// the same stones in the same places are `==`, regardless of move history,
/// which is exactly the property positional superko needs (see `Game`).
public struct Board: Equatable, Hashable, Sendable, Codable {
    public let size: Int
    private var stones: [Stone?]

    /// An empty board of the given size.
    public init(size: Int) {
        precondition(size > 0, "Board size must be positive")
        self.size = size
        self.stones = Array(repeating: nil, count: size * size)
    }

    /// Builds a board directly from a stone layout, bypassing move legality.
    /// For test fixtures and (later) loading saved positions/problems — not
    /// for playing a move, which goes through `placing(_:at:)` instead.
    public init(size: Int, stones: [Point: Stone]) {
        precondition(size > 0, "Board size must be positive")
        self.size = size
        self.stones = Array(repeating: nil, count: size * size)
        for (point, stone) in stones {
            precondition(isOnBoard(point), "\(point) is off a \(size)x\(size) board")
            self.stones[index(of: point)] = stone
        }
    }

    private func index(of point: Point) -> Int { point.y * size + point.x }

    public func isOnBoard(_ point: Point) -> Bool {
        point.x >= 0 && point.x < size && point.y >= 0 && point.y < size
    }

    public subscript(_ point: Point) -> Stone? {
        precondition(isOnBoard(point), "\(point) is off a \(size)x\(size) board")
        return stones[index(of: point)]
    }

    /// The (up to 4) orthogonal on-board neighbors of a point.
    public func neighbors(of point: Point) -> [Point] {
        [
            Point(point.x - 1, point.y),
            Point(point.x + 1, point.y),
            Point(point.x, point.y - 1),
            Point(point.x, point.y + 1),
        ].filter(isOnBoard)
    }

    /// Every point on the board, row by row.
    public var allPoints: [Point] {
        var points: [Point] = []
        points.reserveCapacity(size * size)
        for y in 0..<size {
            for x in 0..<size {
                points.append(Point(x, y))
            }
        }
        return points
    }
}

// MARK: - Groups & liberties

/// A maximal set of same-color stones connected orthogonally, with the set of
/// empty points adjacent to it (its liberties).
public struct Group: Equatable, Sendable {
    public let color: Stone
    public let stones: Set<Point>
    public let liberties: Set<Point>
}

extension Board {
    /// The group containing `point`, or `nil` if `point` is empty.
    public func group(containing point: Point) -> Group? {
        guard let color = self[point] else { return nil }
        var stones: Set<Point> = []
        var liberties: Set<Point> = []
        var stack = [point]
        while let current = stack.popLast() {
            guard stones.insert(current).inserted else { continue }
            for neighbor in neighbors(of: current) {
                switch self[neighbor] {
                case .none:
                    liberties.insert(neighbor)
                case .some(let neighborColor) where neighborColor == color:
                    stack.append(neighbor)
                default:
                    break
                }
            }
        }
        return Group(color: color, stones: stones, liberties: liberties)
    }
}

// MARK: - Placing stones

public enum PlacementError: Error, Equatable, Sendable {
    case offBoard
    case pointOccupied
    /// Placing here captures nothing and leaves the placed stone's own group
    /// with zero liberties. A move that *does* capture, even if the placed
    /// stone ends up with only one liberty afterward, is not suicide.
    case suicide
}

extension Board {
    /// Plays `stone` at `point` and resolves captures, per standard Go rules:
    /// 1. The stone is placed.
    /// 2. Any adjacent enemy group left with zero liberties is captured.
    /// 3. Only then is the placed stone's own group checked — if captures
    ///    happened, it may legally have as few as one liberty; if none
    ///    happened and it has zero, the move is suicide and illegal.
    ///
    /// This ordering is what makes a "self-atari that captures" legal: the
    /// space vacated by a capture counts as a liberty before the suicide
    /// check runs. Ko/superko are not checked here — `Board` has no move
    /// history, so that's `Game`'s responsibility.
    public func placing(_ stone: Stone, at point: Point) throws -> (board: Board, captured: Int) {
        guard isOnBoard(point) else { throw PlacementError.offBoard }
        guard self[point] == nil else { throw PlacementError.pointOccupied }

        var next = self
        next.stones[next.index(of: point)] = stone

        var captured = 0
        let opponent = stone.opponent
        for neighbor in neighbors(of: point) {
            guard next[neighbor] == opponent else { continue }
            guard let group = next.group(containing: neighbor), group.liberties.isEmpty else { continue }
            for capturedPoint in group.stones {
                next.stones[next.index(of: capturedPoint)] = nil
            }
            captured += group.stones.count
        }

        guard let ownGroup = next.group(containing: point), !ownGroup.liberties.isEmpty else {
            throw PlacementError.suicide
        }

        return (next, captured)
    }
}
