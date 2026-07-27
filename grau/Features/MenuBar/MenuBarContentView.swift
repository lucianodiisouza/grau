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
    @State private var menuState: MenuBarState

    @MainActor
    init() {
        // MenuBarState is @MainActor — construct in the struct's
        // init (implicitly @MainActor for a SwiftUI View).
        // See docs/TROUBLESHOOTING.md#strict-concurrency.
        _menuState = State(wrappedValue: MenuBarState())
    }

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
    @MainActor
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
    @MainActor
    private var storageRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            StorageBar(used: menuState.totalBytes - menuState.freeBytes, total: menuState.totalBytes)
        }
    }

    @ViewBuilder
    @MainActor
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
    @MainActor
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
        // The SwiftUI Window scene restores a cached NSWindow
        // frame from defaults, which can shrink the window
        // well below defaultSize after switching to a slim view
        // (Uninstaller) and back. Force the window to the
        // default 1100x720 on every open, then let the user
        // resize from there.
        DispatchQueue.main.async {
            for window in NSApp.windows where window.title == "Grau" {
                if window.frame.width < 900 || window.frame.height < 600 {
                    let target = NSSize(width: 1100, height: 720)
                    var frame = window.frame
                    frame.size = target
                    // Centre on the screen the window is on
                    if let screen = window.screen {
                        let screenFrame = screen.visibleFrame
                        frame.origin.x = screenFrame.midX - target.width / 2
                        frame.origin.y = screenFrame.midY - target.height / 2
                    }
                    window.setFrame(frame, display: true, animate: true)
                }
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

    @MainActor
    private var freeText: String {
        let free = ByteSize(bytes: menuState.freeBytes)
        return "\(free.humanReadable) free"
    }

    @MainActor
    private var trashText: String {
        if menuState.trashSize == 0 {
            return "Empty"
        }
        let size = ByteSize(bytes: menuState.trashSize).humanReadable
        let n = menuState.trashItemCount
        return "\(size) · \(n) item\(n == 1 ? "" : "s")"
    }
}
