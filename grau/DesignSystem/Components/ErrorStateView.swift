//
//  ErrorStateView.swift
//  grau
//
//  Full-area error state. See docs/DESIGN.md § 8.
//

import SwiftUI

public struct ErrorStateView<Action: View>: View {
    public let title: String
    public let message: String
    @ViewBuilder public let action: Action

    public init(
        title: String,
        message: String,
        @ViewBuilder action: () -> Action = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: title,
            message: message,
            action: { action }
        )
    }
}

#Preview {
    ErrorStateView(
        title: "Couldn't scan",
        message: "Permission denied. Grant Full Disk Access to scan system caches.",
        action: { PrimaryButton("Open System Settings") {} }
    )
    .frame(width: 480, height: 360)
}
