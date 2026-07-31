import Foundation
import GoKit

/// The artwork's entire memory: every point that has ever had activity, and
/// how many sessions have touched it so far. This is exactly what gets
/// serialized to `palimpsest.json` — the piece's literal memory file,
/// reloaded and advanced by one session each time it's run.
///
/// Deliberately sparse: a point untouched by any session simply isn't in
/// `points`, rather than storing an empty record for all 169 (13x13)
/// points from the start.
public struct PalimpsestState: Codable, Sendable, Equatable {
    public var boardSize: Int
    public var sessionIndex: Int
    public var points: [PointRecord]

    public init(boardSize: Int) {
        self.boardSize = boardSize
        sessionIndex = 0
        points = []
    }

    public func record(x: Int, y: Int) -> PointRecord? {
        points.first { $0.x == x && $0.y == y }
    }

    /// Finds or creates the record at `(x, y)`, applies `mutate` to it, and
    /// writes it back — the one place point lookups happen, so the "find or
    /// create" logic exists exactly once.
    mutating func withRecord(x: Int, y: Int, _ mutate: (inout PointRecord) -> Void) {
        if let index = points.firstIndex(where: { $0.x == x && $0.y == y }) {
            mutate(&points[index])
        } else {
            var new = PointRecord(x: x, y: y)
            mutate(&new)
            points.append(new)
        }
    }
}

extension PalimpsestState {
    mutating func appendMark(_ mark: Mark, at point: Point) {
        withRecord(x: point.x, y: point.y) { $0.marks.append(mark) }
    }

    /// A capture at `point`: refresh (not duplicate) its scar, resetting age
    /// to 0 so a re-captured point reads as freshly wounded again.
    mutating func recordCapture(at point: Point, sessionIndex: Int) {
        withRecord(x: point.x, y: point.y) {
            $0.scar = Scar(sessionOccurred: sessionIndex, age: 0)
        }
    }

    /// Ages every mark and scar *not* laid/occurred in `sessionIndex` (this
    /// session's own brand-new strata) by one pass: age += 1, and any mark
    /// whose new opacity has crossed `PointRecord.forgottenThreshold` is
    /// removed and folded into that point's residue instead of lingering
    /// forever as an ever-more-transparent entry.
    mutating func ageStrata(exceptSession sessionIndex: Int) {
        for i in points.indices {
            var kept: [Mark] = []
            for var mark in points[i].marks {
                guard mark.sessionLaid != sessionIndex else {
                    kept.append(mark)
                    continue
                }
                mark.age += 1
                if mark.opacity < PointRecord.forgottenThreshold {
                    points[i].residue = min(PointRecord.residueCap, points[i].residue + PointRecord.residueBump)
                } else {
                    kept.append(mark)
                }
            }
            points[i].marks = kept

            if var scar = points[i].scar, scar.sessionOccurred != sessionIndex {
                scar.age += 1
                points[i].scar = scar
            }
        }
    }
}
