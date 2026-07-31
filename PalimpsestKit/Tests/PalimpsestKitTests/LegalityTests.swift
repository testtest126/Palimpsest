import Testing
import GoKit
@testable import PalimpsestKit

struct LegalityTests {
    /// Every move `SoftPolicy` hands back — across many session seeds and
    /// through a full self-play sequence each time — is legal at the exact
    /// moment it's chosen, checked against the same `Game.isLegal` GoKit's
    /// own rules use. The soft/organic bias never bypasses real Go rules.
    @Test func everyMoveThePolicyChoosesIsLegalWhenChosen() {
        for sessionIndex in 1...20 {
            var rng = SeededGenerator(seed: UInt64(sessionIndex))
            var game = Game(size: 13)
            let moveCount = Int.random(in: SessionRunner.moveCountRange, using: &rng)

            for _ in 0..<moveCount {
                guard !game.isOver else { break }
                let move = SoftPolicy.chooseMove(for: game, rng: &rng)
                #expect(game.isLegal(move), "session \(sessionIndex): \(move) was not legal")
                _ = try? game.apply(move)
            }
        }
    }

    /// A full `SessionRunner` run never leaves more stones on any point's
    /// present layer than Go rules allow — i.e., the final board `Game`
    /// builds internally is always a legally-reached position. Checked
    /// indirectly: replaying the same seed's self-play from scratch and
    /// asking `Game` to apply each move must never throw.
    @Test func aFullSessionsMovesApplyWithoutError() throws {
        for sessionIndex in 1...10 {
            var rng = SeededGenerator(seed: UInt64(sessionIndex))
            var game = Game(size: 13)
            let moveCount = Int.random(in: SessionRunner.moveCountRange, using: &rng)
            for _ in 0..<moveCount {
                guard !game.isOver else { break }
                let move = SoftPolicy.chooseMove(for: game, rng: &rng)
                try game.apply(move) // throws (failing the test) if ever illegal
            }
        }
    }
}
