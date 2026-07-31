import Foundation

/// A single stone laid at some point in the palimpsest's history. `age` is
/// aging *passes* elapsed since it was laid — one per completed session,
/// not wall-clock time — incremented by `ageStrata(_:exceptSession:)`.
public struct Mark: Codable, Sendable, Equatable {
    public enum Color: String, Codable, Sendable {
        case black, white
    }

    public var color: Color
    public var sessionLaid: Int
    public var age: Int

    public init(color: Color, sessionLaid: Int, age: Int = 0) {
        self.color = color
        self.sessionLaid = sessionLaid
        self.age = age
    }

    /// The present layer is *the most recent session's* live stones only —
    /// not a fuzzy multi-session window — so this is exactly "was this laid
    /// by the session that just ran, before any aging pass has touched it."
    public var isPresent: Bool { age == 0 }

    /// Exponential decay, no special-casing needed for age 0 (`decay^0 ==
    /// 1.0`, full opacity, exactly the present layer's look).
    public var opacity: Double {
        pow(Mark.decayFactor, Double(age))
    }

    /// Tuned by eye, not measured: ~9-10 aging passes (sessions) before a
    /// mark crosses `PointRecord.forgottenThreshold` and gets forgotten —
    /// long enough that an 6-8 session seed run shows every session's
    /// strata still visibly decaying, none fully gone yet.
    static let decayFactor = 0.72
}

/// A capture, remembered at the point it happened — "a faint ring even
/// after the stone is gone." Unlike a `Mark`, a scar never fully forgets:
/// its opacity asymptotes toward `floor` rather than crossing a threshold
/// and disappearing. A wound outlasts a presence.
public struct Scar: Codable, Sendable, Equatable {
    public var sessionOccurred: Int
    public var age: Int

    public init(sessionOccurred: Int, age: Int = 0) {
        self.sessionOccurred = sessionOccurred
        self.age = age
    }

    public var opacity: Double {
        Scar.floor + (Scar.initial - Scar.floor) * pow(Scar.decay, Double(age))
    }

    /// A ring starts faint (0.55, not a solid stone's 1.0 — it was never a
    /// presence, only ever a mark of one being taken) and settles toward a
    /// permanent 0.12, never zero.
    static let initial = 0.55
    static let floor = 0.12
    static let decay = 0.75
}

/// Everything the palimpsest remembers at one point on the board: active
/// (still-decaying) marks oldest-first, a permanent faint residue left by
/// marks that have already been forgotten, and at most one scar (refreshed,
/// not duplicated, if the same point is captured again in a later session).
public struct PointRecord: Codable, Sendable, Equatable {
    public var x: Int
    public var y: Int
    public var marks: [Mark]
    public var residue: Double
    public var scar: Scar?

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
        marks = []
        residue = 0
        scar = nil
    }

    public var isEmpty: Bool { marks.isEmpty && residue == 0 && scar == nil }

    /// Below this, a mark stops being an actively-tracked, individually
    /// decaying layer and is folded into the point's flat residue instead —
    /// this is what keeps `palimpsest.json` bounded across an unbounded
    /// number of future sessions, rather than growing forever.
    static let forgottenThreshold = 0.05

    /// Each forgotten mark nudges the permanent floor up slightly, capped —
    /// "the board never fully cleans," but it doesn't get muddier forever
    /// either.
    static let residueBump = 0.03
    static let residueCap = 0.15
}
