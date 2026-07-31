import GoKit

/// Runs exactly one new session on top of an existing `PalimpsestState` and
/// returns the result — the whole life cycle described in the README:
/// self-play a handful of real moves, let this session's final stones
/// become the new present layer, age everything older by one pass.
public enum SessionRunner {
    /// How many moves a session lays, before falling back to a shorter run
    /// if the board runs out of room to keep going (`Game.isOver`, or a
    /// legal-move search that only ever finds `.pass`) — never forced.
    static let moveCountRange = 6...10

    /// - Parameter state: the palimpsest as of the last completed session.
    /// - Returns: the new state, one session further on. Deterministic:
    ///   the session's move sequence and every aging step is a pure
    ///   function of `state` and the new session index (seeded via
    ///   `SeededGenerator(seed: UInt64(newSessionIndex))`) — no wall clock,
    ///   no system randomness anywhere in this path.
    public static func runSession(on state: PalimpsestState) -> PalimpsestState {
        var state = state
        let sessionIndex = state.sessionIndex + 1
        var rng = SeededGenerator(seed: UInt64(sessionIndex))

        var game = Game(size: state.boardSize)
        let moveCount = Int.random(in: moveCountRange, using: &rng)
        for _ in 0..<moveCount {
            guard !game.isOver else { break }
            let before = game.board
            let move = SoftPolicy.chooseMove(for: game, rng: &rng)
            // `move` always comes from `game.legalMoves()` (see SoftPolicy),
            // so this can't meaningfully fail — but `apply` is throwing, so
            // handle it rather than force-trying into a crash if that
            // invariant is ever wrong.
            guard (try? game.apply(move)) != nil else { break }
            recordCaptures(&state, before: before, after: game.board, sessionIndex: sessionIndex)
        }

        // This session's final stones — after every capture within its own
        // self-play has already resolved — become the new present layer.
        for point in game.board.allPoints {
            guard let stone = game.board[point] else { continue }
            let color: Mark.Color = stone == .black ? .black : .white
            state.appendMark(Mark(color: color, sessionLaid: sessionIndex, age: 0), at: point)
        }

        // Everything that existed before this session ages by one pass;
        // this session's own brand-new marks/scars are exempted by
        // `ageStrata` matching on `sessionIndex`.
        state.ageStrata(exceptSession: sessionIndex)

        state.sessionIndex = sessionIndex
        return state
    }

    /// Diffs `before`/`after` to find every point that had a stone and now
    /// doesn't — GoKit's `Board.placing`/`Game.apply` report only a capture
    /// *count*, not which points, so this reconstructs it directly rather
    /// than needing GoKit changed to expose more.
    static func recordCaptures(_ state: inout PalimpsestState, before: Board, after: Board, sessionIndex: Int) {
        for point in before.allPoints where before[point] != nil && after[point] == nil {
            state.recordCapture(at: point, sessionIndex: sessionIndex)
        }
    }
}
