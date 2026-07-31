import Testing
import GoKit
@testable import PalimpsestKit

struct AgingTests {
    @Test func markOpacityIsMonotonicallyNonIncreasingWithAge() {
        var previous = Double.infinity
        for age in 0...20 {
            let mark = Mark(color: .black, sessionLaid: 1, age: age)
            #expect(mark.opacity <= previous)
            previous = mark.opacity
        }
    }

    @Test func scarOpacityIsMonotonicallyNonIncreasingAndNeverReachesZero() {
        var previous = Double.infinity
        for age in 0...50 {
            let scar = Scar(sessionOccurred: 1, age: age)
            #expect(scar.opacity <= previous)
            #expect(scar.opacity > 0)
            previous = scar.opacity
        }
    }

    /// Ages nothing get younger — running `ageStrata` repeatedly on the same
    /// point only ever increases every mark's `age` (or removes it into
    /// residue), never decreases it.
    @Test func ageStrataNeverDecreasesAge() {
        var state = PalimpsestState(boardSize: 13)
        state.appendMark(Mark(color: .black, sessionLaid: 1, age: 0), at: Point(3, 3))
        state.sessionIndex = 1

        var lastAge = -1
        for pass in 2...8 {
            state.ageStrata(exceptSession: 0) // 0 never matches sessionLaid, so this ages everything
            state.sessionIndex = pass
            let currentAge = state.record(x: 3, y: 3)?.marks.first?.age
            if let currentAge {
                #expect(currentAge > lastAge)
                lastAge = currentAge
            }
        }
    }

    @Test func aMarkIsForgottenIntoResidueOnceItCrossesTheThreshold() {
        var state = PalimpsestState(boardSize: 13)
        state.appendMark(Mark(color: .white, sessionLaid: 1, age: 0), at: Point(5, 5))

        // Enough passes that opacity (0.72^age) is well below the 0.05
        // forgotten threshold — 0.72^15 ≈ 0.0073.
        for _ in 0..<15 {
            state.ageStrata(exceptSession: -1)
        }

        let record = state.record(x: 5, y: 5)
        #expect(record?.marks.isEmpty == true)
        #expect((record?.residue ?? 0) > 0)
    }

    @Test func residueNeverExceedsItsCap() {
        var state = PalimpsestState(boardSize: 13)
        // Forget many marks at the same point and confirm residue stays capped.
        for session in 1...10 {
            state.appendMark(Mark(color: .black, sessionLaid: session, age: 0), at: Point(1, 1))
            for _ in 0..<15 { state.ageStrata(exceptSession: -1) }
        }
        let residue = state.record(x: 1, y: 1)?.residue ?? 0
        #expect(residue <= PointRecord.residueCap + 1e-9)
    }
}
