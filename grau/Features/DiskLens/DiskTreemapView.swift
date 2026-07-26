//
//  DiskTreemapView.swift
//  grau
//
//  Squarified treemap visualization for the Disk Lens feature.
//  Falls back to the Top-N list when the slice count exceeds
//  the renderer threshold.
//
//  Algorithm: Bruls, Huijsen, van Wijk (2000), "Squarified
//  Treemaps". Items are sorted by size descending and added to
//  the "current row" while adding more doesn't worsen the worst
//  aspect ratio; when it does, the row is committed and a new
//  one starts on the perpendicular axis.
//

import SwiftUI
import graucore

struct DiskTreemapView: View {
    let nodes: [DiskTreeNode]
    let onSelect: (DiskTreeNode) -> Void
    let onReveal: (DiskTreeNode) -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = SquarifiedLayout(
                items: nodes,
                width: proxy.size.width,
                height: proxy.size.height
            )
            ZStack(alignment: .topLeading) {
                ForEach(Array(layout.rects.enumerated()), id: \.offset) { index, rect in
                    let node = nodes[index]
                    treemapCell(node: node, rect: rect)
                        .onTapGesture { onSelect(node) }
                        .contextMenu {
                            Button("Reveal in Finder") { onReveal(node) }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func treemapCell(node: DiskTreeNode, rect: CGRect) -> some View {
        let color = colorFor(node: node)
        ZStack(alignment: .topLeading) {
            color
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.origin.x, y: rect.origin.y)
            // Three label tiers based on cell size.
            if rect.width > 80 && rect.height > 36 {
                // Big enough for the full name + size.
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(node.size.humanReadable)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.xs)
                .frame(width: rect.width, height: rect.height, alignment: .topLeading)
                .offset(x: rect.origin.x, y: rect.origin.y)
            } else if rect.width >= 40 && rect.height >= 18 {
                // Medium: just the size, in a smaller font, in the
                // top-left corner.
                Text(node.size.humanReadable)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(3)
                    .offset(x: rect.origin.x, y: rect.origin.y)
            }
            // else: cell too small — no label.
        }
    }

    private func colorFor(node: DiskTreeNode) -> Color {
        // Hash the name to a stable color in the accent family.
        let hue = Double(abs(node.name.hashValue) % 360) / 360.0
        return Color(hue: hue, saturation: 0.35, brightness: 0.92)
    }
}

// MARK: - Squarified layout

struct SquarifiedLayout {
    let rects: [CGRect]

    init(items: [DiskTreeNode], width: CGFloat, height: CGFloat) {
        guard width > 0, height > 0, !items.isEmpty else {
            self.rects = []
            return
        }
        // Sort items by size descending.
        let sorted = items.sorted { $0.size.bytes > $1.size.bytes }
        let total = sorted.reduce(Double(0)) { $0 + Double($1.size.bytes) }
        guard total > 0 else {
            self.rects = []
            return
        }
        // Normalize sizes to the total area.
        let area = Double(width) * Double(height)
        let scale = area / total
        let scaled = sorted.map { Double($0.size.bytes) * scale }
        self.rects = Self.layout(
            values: scaled,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }

    /// Squarified algorithm. `values` are the scaled areas.
    private static func layout(values: [Double], in rect: CGRect) -> [CGRect] {
        var result: [CGRect] = []
        var remaining = values
        var bounds = rect
        var currentRow: [Double] = []

        while !remaining.isEmpty {
            if currentRow.isEmpty {
                currentRow = [remaining[0]]
                remaining.removeFirst()
                continue
            }
            let improved = worstAspect(
                row: currentRow + [remaining[0]],
                shortSide: min(bounds.width, bounds.height)
            ) < worstAspect(row: currentRow, shortSide: min(bounds.width, bounds.height))
            if improved {
                currentRow.append(remaining[0])
                remaining.removeFirst()
            } else {
                // Commit the current row along the shorter side.
                let rects = layoutRow(row: currentRow, in: bounds)
                result.append(contentsOf: rects)
                bounds = shrink(bounds, by: currentRow, orientation: bounds.width < bounds.height ? .vertical : .horizontal)
                currentRow = []
            }
        }
        if !currentRow.isEmpty {
            result.append(contentsOf: layoutRow(row: currentRow, in: bounds))
        }
        return result
    }

    private enum Axis { case vertical, horizontal }

    /// Lays out a single row. When the bounding box is wider than
    /// tall, the row is laid out vertically (stacked top-to-bottom);
    /// otherwise horizontally.
    private static func layoutRow(row: [Double], in bounds: CGRect) -> [CGRect] {
        let rowSum = row.reduce(0, +)
        guard rowSum > 0 else { return [] }
        let vertical = bounds.width < bounds.height
        if vertical {
            // Stack top-to-bottom; each cell takes the full width.
            let rowWidth = rowSum / Double(bounds.height)
            var y: Double = Double(bounds.origin.y)
            var rects: [CGRect] = []
            for v in row {
                let h = v / rowWidth
                rects.append(CGRect(
                    x: Double(bounds.origin.x),
                    y: y,
                    width: rowWidth,
                    height: h
                ))
                y += h
            }
            return rects
        } else {
            // Stack left-to-right; each cell takes the full height.
            let rowHeight = rowSum / Double(bounds.width)
            var x: Double = Double(bounds.origin.x)
            var rects: [CGRect] = []
            for v in row {
                let w = v / rowHeight
                rects.append(CGRect(
                    x: x,
                    y: Double(bounds.origin.y),
                    width: w,
                    height: rowHeight
                ))
                x += w
            }
            return rects
        }
    }

    private static func shrink(_ bounds: CGRect, by row: [Double], orientation: Axis) -> CGRect {
        let rowSum = row.reduce(0, +)
        guard rowSum > 0 else { return bounds }
        switch orientation {
        case .vertical:
            // The row was laid out vertically; the new bounds is
            // to the right, and width shrinks.
            let rowWidth = rowSum / Double(bounds.height)
            return CGRect(
                x: bounds.origin.x + CGFloat(rowWidth),
                y: bounds.origin.y,
                width: bounds.width - CGFloat(rowWidth),
                height: bounds.height
            )
        case .horizontal:
            // The row was laid out horizontally; the new bounds is
            // below, and height shrinks.
            let rowHeight = rowSum / Double(bounds.width)
            return CGRect(
                x: bounds.origin.x,
                y: bounds.origin.y + CGFloat(rowHeight),
                width: bounds.width,
                height: bounds.height - CGFloat(rowHeight)
            )
        }
    }

    /// Computes the worst aspect ratio in the current row. Lower
    /// is better; 1.0 means every rectangle is a perfect square.
    private static func worstAspect(row: [Double], shortSide: CGFloat) -> Double {
        guard let maxV = row.max(), let minV = row.min(), maxV > 0 else { return .infinity }
        let s2 = Double(shortSide) * Double(shortSide)
        let sum = row.reduce(0, +)
        let s2Sum = s2 * sum
        let maxS2 = s2 * maxV
        return max(
            (s2Sum * maxV) / (maxS2 * maxS2),
            (maxS2 * maxS2) / (s2Sum * minV)
        )
    }
}
