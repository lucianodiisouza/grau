//
//  grauApp.swift
//  grau
//
//  @main entry point. Three scenes:
//    1. MenuBarExtra — always present, popover style
//    2. Main window — dashboard / feature tabs (or onboarding if
//       first launch)
//    3. Settings window
//
//  See docs/HANDOFF.md § 0.4 and docs/ARCHITECTURE.md § 3.
//

import SwiftUI

@main
struct grauApp: App {
    @State private var appVM = AppViewModel()
    @State private var notificationCoordinator = NotificationCoordinator()

    var body: some Scene {
        MenuBarExtra("Grau", systemImage: "circle.fill") {
            MenuBarContentView()
                .environment(appVM)
        }
        .menuBarExtraStyle(.window)

        Window("Grau", id: "main") {
            Group {
                if appVM.hasOnboarded {
                    MainWindowView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appVM)
            .frame(minWidth: 720, minHeight: 480)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Grau") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(after: .newItem) {
                Button("Open Grau") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .environment(appVM)
                .frame(minWidth: 480, minHeight: 320)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 360)
    }
}
