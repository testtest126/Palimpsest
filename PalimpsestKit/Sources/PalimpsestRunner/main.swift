import Foundation
import PalimpsestKit

/// Advances Palimpsest by exactly one session: load `palimpsest.json` (or
/// start fresh if it doesn't exist yet), self-play, age, save, render.
/// Every invocation is this same, small life cycle — see the README for
/// why that's the point, not a limitation.
///
/// Usage: `palimpsest-run [directory]` — defaults to the current directory.
/// Reads/writes `<directory>/palimpsest.json` and `<directory>/render.svg`.

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

let stateURL = directory.appendingPathComponent("palimpsest.json")
let svgURL = directory.appendingPathComponent("render.svg")

let boardSize = 13

do {
    let before = try Persistence.load(from: stateURL, boardSize: boardSize)
    let after = SessionRunner.runSession(on: before)
    try Persistence.save(after, to: stateURL)

    let svg = Renderer.render(after)
    try svg.write(to: svgURL, atomically: true, encoding: .utf8)

    let activePoints = after.points.filter { !$0.isEmpty }.count
    print("Session \(after.sessionIndex) complete — \(activePoints) points carry memory.")
    print("Wrote \(stateURL.path)")
    print("Wrote \(svgURL.path)")
} catch {
    FileHandle.standardError.write("palimpsest-run failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
