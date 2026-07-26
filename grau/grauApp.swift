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
//  Phase 6b wires in Sparkle for self-update. The standard
//  updater controller reads SUFeedURL / SUPublicEDKey from
//  Info.plist. The user gets a "Check for Updates" item in
//  the app menu and Sparkle also checks on launch (toggleable
//  via SUEnableAutomaticChecks in Info.plist).
//

import SwiftUI
import Sparkle

@main
struct grauApp: App {
    @State private var appVM: AppViewModel
    @State private var notificationCoordinator: NotificationCoordinator

    /// We need `openWindow` inside `commands { ... }` to wire the
    /// "Open Grau" menu item (Cmd+0) to actually open the main
    /// window. `openWindow` is only available via `@Environment`,
    /// which can only be read from inside `body`. We bridge it
    /// through a single-use helper that captures the value when
    /// `body` is first evaluated.
    @Environment(\.openWindow) private var openWindow

    /// Sparkle 2.x standard updater. Started immediately so the
    /// feed is checked on the first launch after install.
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Explicit init is required because AppViewModel and
        // NotificationCoordinator are @MainActor — Swift's
        // property-initializer context isn't, so the default
        // `@State private var x = X()` form errors under
        // StrictConcurrency (which is enabled in project.yml).
        // `App.init()` is implicitly @MainActor, so it's safe to
        // construct the MainActor-isolated view models here.
        _appVM = State(wrappedValue: AppViewModel())
        _notificationCoordinator = State(wrappedValue: NotificationCoordinator())
        // startingUpdater: true → SPUUpdater is created and the
        // first feed check is queued. We do NOT pass a custom
        // updater delegate; the default behavior is fine for v1.1.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Start as an accessory app (no Dock icon) so Grau behaves
        // like a menu-bar app from the moment it launches. The Dock
        // icon is promoted to `.regular` only when a window is
        // actually opened — see DockIconController.
        //
        // We call `NSApplication.shared` (not the `NSApp` global)
        // because `NSApp` is still nil at this point in the SwiftUI
        // `App.init()` lifecycle. Touching `NSApplication.shared`
        // initializes the singleton and returns it. The `NSApp`
        // global will be populated by the time `body` is evaluated.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(appVM)
        } label: {
            // Template image at 18pt @2x (36x36 px). macOS tints
            // it for light/dark menu bar automatically and slots
            // it into the standard template size. Do NOT
            // resizable()/frame() — those modifiers are ignored
            // by MenuBarExtra, which uses the image at its native
            // template size. The 18pt slot matches every other
            // template icon next to it in the menu bar; a larger
            // canvas (e.g. 22pt) makes the icon look oversized.
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        // The SwiftUI `Window` scene is single-instance and
        // restores a cached frame from defaults on subsequent
        // presentations. We rely on defaultSize + minWidth/
        // minHeight for the initial size and reset the cached
        // frame on first open (see openMainWindow()).
        Window("Grau", id: "main") {
            Group {
                if appVM.hasOnboarded {
                    MainWindowView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appVM)
            .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Grau") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(after: .newItem) {
                Button("Open Grau") {
                    // Promote to .regular before showing the window so
                    // the Dock icon and the window appear together,
                    // without a one-frame flicker. DockIconController
                    // takes over the policy from this point on.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            // "Check for Updates..." menu item. Sparkle's
            // SPUUpdater.checkForUpdates() triggers the user
            // driver (default NSAlert flow) and surfaces the
            // standard Sparkle UI.
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.updater.checkForUpdates()
                }
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
