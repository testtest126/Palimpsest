import Foundation

/// `palimpsest.json` — the artwork's literal memory file. Loaded at the
/// start of every run, advanced by exactly one session, written back at
/// the end. If it doesn't exist yet, a fresh, empty 13x13 state is used —
/// the piece's very first session.
public enum Persistence {
    public static func load(from url: URL, boardSize: Int) throws -> PalimpsestState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return PalimpsestState(boardSize: boardSize)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PalimpsestState.self, from: data)
    }

    public static func save(_ state: PalimpsestState, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }
}
