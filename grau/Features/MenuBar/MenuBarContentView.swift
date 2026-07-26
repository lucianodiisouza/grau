//
//  MenuBarContentView.swift
//  grau
//
//  Popover content for the menu bar item. See docs/DESIGN.md § 3.2.
//  Real layout (storage bar, quick actions, status section) lands
//  in Phase 1 Task 1.11.
//

import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Grau")
                .font(.headline)
            Text("Menu bar popover — full content lands in Task 1.11.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Open Grau") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)
        }
        .padding(Spacing.lg)
        .frame(width: 320)
    }
}

#Preview {
    MenuBarContentView()
        .environment(AppViewModel())
}
