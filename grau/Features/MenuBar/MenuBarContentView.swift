//
//  MenuBarContentView.swift
//  grau
//
//  The 320pt popover shown when the menu bar item is clicked.
//  See docs/DESIGN.md § 3.2.
//

import SwiftUI
import graucore

struct MenuBarContentView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.openWindow) private var openWindow
    @State private var menuState = MenuBarState()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            Divider()
            storageRow
            trashRow
            quickActions
            Spacer(minLength: Spacing.sm)
            Divider()
            footer
        }
        .padding(Spacing.lg)
        .frame(width: 320)
        .task {
            menuState.start(interval: 30)
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Grau")
                .font(.headline)
            Text(freeText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var storageRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            StorageBar(used: menuState.totalBytes - menuState.freeBytes, total: menuState.totalBytes)
        }
    }

    @ViewBuilder
    private var trashRow: some View {
        HStack {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text("Trash")
                    .font(.callout)
                Text(trashText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var quickActions: some View {
        VStack(spacing: Spacing.xs) {
            SecondaryButton("Dar um Grau", systemImage: "macwindow") {
                openMainWindow()
            }
            SecondaryButton("Empty Trash", systemImage: "trash.slash", isEnabled: menuState.trashSize > 0) {
                // Open Finder with Trash selected; user confirms empty in Finder
                NSWorkspace.shared.activateFileViewerSelecting(
                    [URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")]
                )
            }
            Divider()
            DestructiveButton("Quit Grau", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
    }

    private func openMainWindow() {
        // `openWindow(id:)` alone sometimes fails to surface the
        // window when the menu bar extra has captured focus; bring
        // the app forward first, then request the scene.
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
        // Belt-and-suspenders: if the scene already exists but is
        // hidden behind another app's window, order it front.
        DispatchQueue.main.async {
            for window in NSApp.windows where window.identifier?.rawValue.contains("main") == true
                || window.title == "Grau" {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Text("Grau v0.2.0-beta.1")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var freeText: String {
        let free = ByteSize(bytes: menuState.freeBytes)
        return "\(free.humanReadable) free"
    }

    private var trashText: String {
        if menuState.trashSize == 0 {
            return "Empty"
        }
        let size = ByteSize(bytes: menuState.trashSize).humanReadable
        let n = menuState.trashItemCount
        return "\(size) · \(n) item\(n == 1 ? "" : "s")"
    }
}
