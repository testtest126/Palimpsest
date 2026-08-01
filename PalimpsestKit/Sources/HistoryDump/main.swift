import Foundation
import PalimpsestKit

/// Regenerates the palimpsest's ENTIRE history from scratch — sessions
/// 1...N replayed in order — and dumps a compact per-session snapshot array
/// for the website's Timeline scrubber. `SessionRunner.runSession` is a pure
/// function of (state, session index): its RNG is seeded only from the
/// session index, with no wall-clock randomness anywhere. So replaying from
/// an empty state through session N reproduces, bit-for-bit, the same
/// sequence that actually produced the current `palimpsest.json` — this
/// tool never treats that file as a starting point, only as the target
/// session count to replay to (and a check that the replay lands exactly
/// on the real thing).
///
/// Usage: history-dump <directory> [outFile]
/// Reads <directory>/palimpsest.json only to learn the target session
/// count and board size. Writes <directory>/history.json by default.

struct HistoryFile: Codable {
    var boardSize: Int
    /// sessions[i] is the snapshot after session i+1. Each snapshot is an
    /// array of per-point tuples: [x, y, residue, scarOpacity, color1,
    /// opacity1, color2, opacity2, ...] — one (color, opacity) pair per
    /// still-active mark at that point, oldest first, colors as 0=black/
    /// 1=white. Matches Renderer.swift's draw order exactly (residue, scar,
    /// then marks oldest-to-newest) so the page can render it without
    /// re-deriving any of the decay math.
    var sessions: [[[Double]]]
}

func round2(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}

func snapshotTuple(for record: PointRecord) -> [Double] {
    var tuple: [Double] = [
        Double(record.x), Double(record.y),
        round2(record.residue), round2(record.scar?.opacity ?? 0),
    ]
    for mark in record.marks {
        tuple.append(mark.color == .black ? 0 : 1)
        tuple.append(round2(mark.opacity))
    }
    return tuple
}

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let outURL = arguments.count > 2
    ? URL(fileURLWithPath: arguments[2])
    : directory.appendingPathComponent("history.json")
let stateURL = directory.appendingPathComponent("palimpsest.json")

do {
    let target = try Persistence.load(from: stateURL, boardSize: 13)
    let targetSession = target.sessionIndex
    guard targetSession > 0 else {
        print("history-dump: session 0, nothing to replay yet")
        exit(0)
    }

    var state = PalimpsestState(boardSize: target.boardSize)
    var sessions: [[[Double]]] = []
    sessions.reserveCapacity(targetSession)

    for _ in 1...targetSession {
        state = SessionRunner.runSession(on: state)
        let snapshot = state.points
            .filter { !$0.isEmpty }
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            .map(snapshotTuple)
        sessions.append(snapshot)
    }

    guard state == target else {
        FileHandle.standardError.write(
            "history-dump: replay diverged from palimpsest.json — refusing to write a mismatched history\n"
                .data(using: .utf8)!
        )
        exit(1)
    }

    let history = HistoryFile(boardSize: state.boardSize, sessions: sessions)
    let encoder = JSONEncoder()
    // Deterministic byte output (not just deterministic data) — JSONEncoder
    // otherwise orders keys by Swift's per-process-randomized Dictionary
    // hashing, so two runs over identical data could differ byte-for-byte.
    // Same reasoning as Persistence.swift's encoder.
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(history)
    try data.write(to: outURL, options: .atomic)
    print("history-dump: wrote \(targetSession) sessions (\(data.count) bytes) to \(outURL.path)")
} catch {
    FileHandle.standardError.write("history-dump failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
