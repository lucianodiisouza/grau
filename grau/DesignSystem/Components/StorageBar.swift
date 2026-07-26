//
//  StorageBar.swift
//  grau
//
//  Horizontal used/free bar. See docs/DESIGN.md § 3.2.
//

import SwiftUI

public struct StorageBar: View {
    public let used: Int64
    public let total: Int64

    public init(used: Int64, total: Int64) {
        self.used = used
        self.total = total
    }

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    private var freeText: String {
        ByteCountFormatter.string(fromByteCount: max(total - used, 0), countStyle: .file)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("grau-gray-200"))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("grau-accent"))
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 4)
            Text("\(freeText) free")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storage: \(freeText) free of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        StorageBar(used: 237_400_000_000, total: 500_100_000_000)
        StorageBar(used: 100, total: 1000)
    }
    .padding()
    .frame(width: 280)
}
