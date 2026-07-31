import Foundation

public enum MoveError: Error, Equatable, Sendable {
    /// Two passes in a row already ended the game (see `Game.isOver`).
    case gameAlreadyOver
    case illegalPlacement(PlacementError)
    /// The move would recreate a whole-board stone position that has
    /// occurred earlier in the game. See `Game`'s doc comment for why this
    /// one check covers both simple ko and longer superko cycles.
    case positionalSuperko
}

/// A Go game in progress: a `Board` plus whose turn it is, the running
/// capture counts, and enough history to enforce the ko rule.
///
/// **Ko, unified as positional superko.** Rather than implementing "forbid
/// immediate recapture" (simple ko) and "forbid recreating any earlier
/// position" (superko) as two separate mechanisms, `Game` implements only
/// the second, more general one: every move's resulting position is checked
/// against *every* prior position in the game, not just the immediately
/// preceding one. Simple ko is a 2-ply-cycle special case of that same check,
/// so nothing extra is needed to catch it — see `KoTests.swift` for both a
/// direct immediate-recapture case and a longer cycle (a "double ko" plus an
/// intervening pass) that only the full-history check catches. This is
/// positional, not situational, superko: recreating a position is forbidden
/// regardless of whose turn it is this time versus last time.
public struct Game: Sendable {
    public private(set) var board: Board
    public let size: Int
    public let komi: Double
    public private(set) var turn: Stone
    public private(set) var consecutivePasses: Int
    /// White stones Black has captured.
    public private(set) var capturedByBlack: Int
    /// Black stones White has captured.
    public private(set) var capturedByWhite: Int
    private var positionHistory: Set<Board>

    public init(size: Int, komi: Double = 7.5) {
        self.size = size
        self.komi = komi
        self.board = Board(size: size)
        self.turn = .black
        self.consecutivePasses = 0
        self.capturedByBlack = 0
        self.capturedByWhite = 0
        self.positionHistory = [board]
    }

    /// Starts a game from an already-set-up position — for test fixtures and
    /// (later) loading saved positions or problems. `board` seeds the
    /// superko history as the first entry, same as the empty board does for
    /// `init(size:komi:)`.
    public init(board: Board, turn: Stone, komi: Double = 7.5) {
        self.size = board.size
        self.komi = komi
        self.board = board
        self.turn = turn
        self.consecutivePasses = 0
        self.capturedByBlack = 0
        self.capturedByWhite = 0
        self.positionHistory = [board]
    }

    /// True once two passes have happened back to back. A real move in
    /// between resets the count, so pass / play / pass does *not* end the
    /// game — only two consecutive passes do.
    public var isOver: Bool { consecutivePasses >= 2 }

    /// Applies `move` for the player whose turn it currently is. Returns the
    /// number of stones captured by this move (0 for a pass or a capture-less
    /// play). Throws and leaves the game unchanged if the move is illegal.
    @discardableResult
    public mutating func apply(_ move: Move) throws -> Int {
        guard !isOver else { throw MoveError.gameAlreadyOver }

        switch move {
        case .pass:
            consecutivePasses += 1
            turn = turn.opponent
            return 0

        case .play(let point):
            let placement: (board: Board, captured: Int)
            do {
                placement = try board.placing(turn, at: point)
            } catch let error as PlacementError {
                throw MoveError.illegalPlacement(error)
            }

            guard !positionHistory.contains(placement.board) else {
                throw MoveError.positionalSuperko
            }

            board = placement.board
            positionHistory.insert(board)
            consecutivePasses = 0
            if turn == .black {
                capturedByBlack += placement.captured
            } else {
                capturedByWhite += placement.captured
            }
            turn = turn.opponent
            return placement.captured
        }
    }

    /// Whether `move` is legal for `turn` right now, without applying it.
    /// Once the game is over, nothing is legal — not even `pass` (mirrors
    /// `apply` throwing `.gameAlreadyOver` for any move at that point).
    public func isLegal(_ move: Move) -> Bool {
        guard !isOver else { return false }
        switch move {
        case .pass:
            return true
        case .play(let point):
            guard let placement = try? board.placing(turn, at: point) else { return false }
            return !positionHistory.contains(placement.board)
        }
    }

    /// Every move `turn` may legally make right now: `.pass` (always legal,
    /// per the rules of Go — see `isLegal`'s note on `isOver` for the one
    /// exception) plus every point that isn't suicide and doesn't recreate an
    /// earlier position. Written for correctness over speed — Phase 2 has no
    /// need yet for anything faster than checking every point on the board.
    public func legalMoves() -> [Move] {
        guard !isOver else { return [] }
        var moves: [Move] = [.pass]
        for point in board.allPoints where isLegal(.play(point)) {
            moves.append(.play(point))
        }
        return moves
    }
}
