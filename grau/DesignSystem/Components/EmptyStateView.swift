//
//  EmptyStateView.swift
//  grau
//
//  Full-area empty state. See docs/DESIGN.md § 7.
//

import SwiftUI

public struct EmptyStateView<Action: View>: View {
    public let icon: String
    public let title: String
    public let message: String
    @ViewBuilder public let action: Action

    public init(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder action: () -> Action = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            action
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xxl)
    }
}

#Preview {
    EmptyStateView(
        icon: "trash",
        title: "All clear",
        message: "No cleanable junk found.",
        action: { PrimaryButton("Scan again") {} }
    )
    .frame(width: 480, height: 360)
}
