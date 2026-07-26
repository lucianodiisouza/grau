//
//  CardView.swift
//  grau
//
//  Generic card container with system material + 12pt corner radius.
//  See docs/DESIGN.md § 2.4.
//

import SwiftUI

public struct CardView<Content: View>: View {
    @ViewBuilder public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.lg)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(Color("grau-gray-200"), lineWidth: 0.5)
            )
    }
}

#Preview {
    CardView {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Storage")
                .font(.headline)
            Text("237.4 GB used of 500.1 GB")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .frame(width: 320)
}
