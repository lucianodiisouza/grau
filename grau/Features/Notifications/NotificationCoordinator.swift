//
//  NotificationCoordinator.swift
//  grau
//
//  Stub for the Notification Coordinator feature. Real implementation in
//  docs/TASKS.md. For now, just a placeholder so the
//  navigation graph compiles.
//

import SwiftUI

struct NotificationCoordinator: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        EmptyStateView(
            icon: "hammer",
            title: "Notification Coordinator",
            message: "Coming in a later phase. See docs/TASKS.md.",
            action: { PrimaryButton("Open Dashboard") { NSApp.activate(ignoringOtherApps: true) } }
        )
    }
}

#Preview {
    NotificationCoordinator()
        .environment(AppViewModel())
        .frame(width: 800, height: 500)
}
