import Foundation
import Testing
import GoKit
@testable import PalimpsestKit

struct DeterminismTests {
    /// Same starting state, same resulting session index (which is what
    /// seeds the RNG) -> the exact same next state, every field: same
    /// moves self-played, same captures, same aging. No wall clock, no
    /// system randomness anywhere in `SessionRunner`.
    @Test func sameStateProducesTheSameNextStateEveryTime() {
        var seed = PalimpsestState(boardSize: 9)
        seed.appendMark(Mark(color: .black, sessionLaid: 1, age: 3), at: Point(4, 4))
        seed.sessionIndex = 4

        let resultA = SessionRunner.runSession(on: seed)
        let resultB = SessionRunner.runSession(on: seed)

        #expect(resultA == resultB)
    }

    @Test func determinismHoldsAcrossManySessionsInARow() {
        var chainA = PalimpsestState(boardSize: 9)
        var chainB = PalimpsestState(boardSize: 9)
        for _ in 0..<8 {
            chainA = SessionRunner.runSession(on: chainA)
            chainB = SessionRunner.runSession(on: chainB)
        }
        #expect(chainA == chainB)
    }

    /// Encoding/decoding round-trips exactly — the persisted file really is
    /// the whole memory, nothing reconstructed differently on reload.
    @Test func stateSurvivesAJSONRoundTrip() throws {
        var state = PalimpsestState(boardSize: 13)
        for _ in 0..<3 { state = SessionRunner.runSession(on: state) }

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PalimpsestState.self, from: data)

        #expect(decoded == state)
    }
}
