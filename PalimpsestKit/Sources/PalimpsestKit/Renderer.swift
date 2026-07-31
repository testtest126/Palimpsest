import Foundation
import GoKit

/// Renders the current palimpsest as a single self-contained SVG string —
/// no external assets, no fonts, no script. Same warm-wood/slate/shell
/// identity as GoMate, since this is the same maker's Go palette, not a
/// coincidence.
///
/// Draw order at each point (back to front): residue (a colorless stain —
/// what's left once a mark's specific color has been forgotten), scar (a
/// faint ring), then every still-active mark oldest first, so a newer,
/// more opaque layer visually sits over an older, fainter one — the
/// palimpsest's bleed-through, drawn literally.
public enum Renderer {
    private static let imageSize: Double = 900
    private static let margin: Double = 64

    // GoMate's light-mode palette (docs/design/moodboard, GoMate/app/Sources/Theme.swift).
    private static let boardField = "#C8A96A"
    private static let gridLine = "#6E5530"
    private static let hoshiColor = "#6E5530"
    private static let stoneBlack = "#1A1A1A"
    private static let stoneWhite = "#F4F1EA"
    private static let scarInk = "#7A3B2E"
    private static let residueInk = "#5C4A2E"

    public static func render(_ state: PalimpsestState) -> String {
        let n = state.boardSize
        let span = imageSize - margin * 2
        let spacing = n > 1 ? span / Double(n - 1) : 0

        func center(_ x: Int, _ y: Int) -> (Double, Double) {
            (margin + Double(x) * spacing, margin + Double(y) * spacing)
        }

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(fmt(imageSize)) \(fmt(imageSize))" width="\(Int(imageSize))" height="\(Int(imageSize))">
        <title>Palimpsest — session \(state.sessionIndex)</title>
        <rect x="0" y="0" width="\(fmt(imageSize))" height="\(fmt(imageSize))" fill="\(boardField)" rx="14"/>

        """

        // Grid.
        svg += "<g stroke=\"\(gridLine)\" stroke-opacity=\"0.55\" stroke-width=\"1.5\">\n"
        for i in 0..<n {
            let a = margin + Double(i) * spacing
            svg += "<line x1=\"\(fmt(a))\" y1=\"\(fmt(margin))\" x2=\"\(fmt(a))\" y2=\"\(fmt(margin + span))\"/>\n"
            svg += "<line x1=\"\(fmt(margin))\" y1=\"\(fmt(a))\" x2=\"\(fmt(margin + span))\" y2=\"\(fmt(a))\"/>\n"
        }
        svg += "</g>\n"

        // Hoshi (star points) — the 13x13 layout.
        let hoshi = hoshiPoints(for: n)
        if !hoshi.isEmpty {
            svg += "<g fill=\"\(hoshiColor)\">\n"
            for point in hoshi {
                let (cx, cy) = center(point.x, point.y)
                svg += "<circle cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"4.5\"/>\n"
            }
            svg += "</g>\n"
        }

        // Points with any memory at all — sorted for deterministic output.
        let activePoints = state.points
            .filter { !$0.isEmpty }
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }

        let stoneRadius = spacing * 0.44

        for record in activePoints {
            let (cx, cy) = center(record.x, record.y)

            if record.residue > 0 {
                svg += circle(cx: cx, cy: cy, r: stoneRadius * 0.9, fill: residueInk, opacity: record.residue)
            }

            if let scar = record.scar {
                svg += "<circle cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"\(fmt(stoneRadius * 0.72))\" fill=\"none\" stroke=\"\(scarInk)\" stroke-opacity=\"\(fmt(scar.opacity))\" stroke-width=\"2.5\"/>\n"
            }

            for mark in record.marks {
                let fill = mark.color == .black ? stoneBlack : stoneWhite
                svg += circle(cx: cx, cy: cy, r: stoneRadius, fill: fill, opacity: mark.opacity)
                if mark.color == .white {
                    svg += "<circle cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"\(fmt(stoneRadius))\" fill=\"none\" stroke=\"\(stoneBlack)\" stroke-opacity=\"\(fmt(mark.opacity))\" stroke-width=\"1.4\"/>\n"
                }
            }
        }

        svg += "</svg>\n"
        return svg
    }

    private static func circle(cx: Double, cy: Double, r: Double, fill: String, opacity: Double) -> String {
        "<circle cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"\(fmt(r))\" fill=\"\(fill)\" fill-opacity=\"\(fmt(opacity))\"/>\n"
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Same standard 13x13 star-point layout GoMate's `BoardView` uses.
    private static func hoshiPoints(for n: Int) -> [Point] {
        switch n {
        case 9: return [Point(2, 2), Point(2, 6), Point(6, 2), Point(6, 6), Point(4, 4)]
        case 13: return [Point(3, 3), Point(3, 9), Point(9, 3), Point(9, 9), Point(6, 6)]
        case 19:
            return [
                Point(3, 3), Point(3, 9), Point(3, 15),
                Point(9, 3), Point(9, 9), Point(9, 15),
                Point(15, 3), Point(15, 9), Point(15, 15),
            ]
        default: return []
        }
    }
}
