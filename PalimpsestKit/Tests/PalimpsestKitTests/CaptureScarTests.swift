import Testing
import GoKit
@testable import PalimpsestKit

struct CaptureScarTests {
    /// Hand-crafted before/after boards (no RNG involved) so this tests the
    /// capture -> scar wiring directly and deterministically: a single
    /// white stone at (1,1) is captured, `recordCaptures` must diff that
    /// and leave a scar at exactly that point, nowhere else.
    @Test func aCaptureLeavesAScarAtExactlyThatPoint() {
        let before = Board(size: 5, stones: [
            Point(1, 0): .black, Point(0, 1): .black,
            Point(1, 1): .white,
            Point(2, 1): .black, Point(1, 2): .black,
        ])
        let after = Board(size: 5, stones: [
            Point(1, 0): .black, Point(0, 1): .black,
            Point(2, 1): .black, Point(1, 2): .black,
        ])

        var state = PalimpsestState(boardSize: 5)
        SessionRunner.recordCaptures(&state, before: before, after: after, sessionIndex: 3)

        let scarred = state.record(x: 1, y: 1)?.scar
        #expect(scarred?.sessionOccurred == 3)
        #expect(scarred?.age == 0)

        // Nowhere else got a scar.
        #expect(state.points.count == 1)
    }

    @Test func recapturingTheSamePointRefreshesRatherThanDuplicates() {
        let before = Board(size: 5, stones: [Point(2, 2): .white])
        let after = Board(size: 5, stones: [:])

        var state = PalimpsestState(boardSize: 5)
        SessionRunner.recordCaptures(&state, before: before, after: after, sessionIndex: 1)
        SessionRunner.recordCaptures(&state, before: before, after: after, sessionIndex: 5)

        #expect(state.points.count == 1)
        #expect(state.record(x: 2, y: 2)?.scar?.sessionOccurred == 5)
        #expect(state.record(x: 2, y: 2)?.scar?.age == 0)
    }

    @Test func noStoneDisappearingMeansNoScar() {
        let before = Board(size: 5, stones: [Point(0, 0): .black])
        let after = Board(size: 5, stones: [Point(0, 0): .black, Point(1, 0): .white])

        var state = PalimpsestState(boardSize: 5)
        SessionRunner.recordCaptures(&state, before: before, after: after, sessionIndex: 2)

        #expect(state.points.isEmpty)
    }

    /// An end-to-end check that real self-play sessions do produce scars
    /// sometimes (not just the isolated unit above) — sweeps a handful of
    /// session seeds on a small board, where stones packed into 6-10 moves
    /// on limited space make captures common, and requires at least one.
    @Test func realSelfPlaySometimesProducesACapture() {
        var sawAScar = false
        var state = PalimpsestState(boardSize: 7)
        for _ in 0..<15 {
            state = SessionRunner.runSession(on: state)
            if state.points.contains(where: { $0.scar != nil }) {
                sawAScar = true
                break
            }
        }
        #expect(sawAScar)
    }
}
