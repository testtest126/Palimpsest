import GoKit

/// Chooses each session's moves. Deliberately not a strong engine — an
/// artwork wants organic shapes, not a fight for advantage — so this is a
/// soft, weighted-random policy: mostly plays near stones already on the
/// board (clustering into loose, natural-looking shapes rather than
/// scattering evenly across all 169 points), otherwise picks uniformly
/// among whatever's legal. Still real Go throughout: every candidate comes
/// from `Game.legalMoves()`, so captures and illegal-move rejection are
/// exactly GoKit's rules, never faked.
public enum SoftPolicy {
    /// Chance a move lands adjacent to an existing stone rather than
    /// anywhere legal — tuned by eye for "loose clusters," not measured.
    static let clusterBias = 0.7

    public static func chooseMove(for game: Game, rng: inout SeededGenerator) -> Move {
        let legalPoints: [Point] = game.legalMoves().compactMap {
            if case .play(let point) = $0 { return point }
            return nil
        }
        guard !legalPoints.isEmpty else { return .pass }

        let occupied = Set(game.board.allPoints.filter { game.board[$0] != nil })
        if !occupied.isEmpty, Double.random(in: 0..<1, using: &rng) < clusterBias {
            let clustered = legalPoints.filter { point in
                game.board.neighbors(of: point).contains { occupied.contains($0) }
            }
            if !clustered.isEmpty {
                return .play(clustered[Int.random(in: 0..<clustered.count, using: &rng)])
            }
        }
        return .play(legalPoints[Int.random(in: 0..<legalPoints.count, using: &rng)])
    }
}
