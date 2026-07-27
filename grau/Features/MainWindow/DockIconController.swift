//
//  DockIconController.swift
//  grau
//
//  Keeps the Dock icon in sync with the dashboard window:
//  - Window visible  → NSApp activation policy `.regular` (Dock shows).
//  - Window hidden   → `.accessory` (Dock hides).
//
//  Grau is a menu-bar-first app. We don't set `LSUIElement` in
//  Info.plist because the user wants the Dock icon to appear
//  whenever the dashboard window is open, and disappear whenever
//  it isn't. Switching the activation policy at runtime gives us
//  that behaviour without two code paths.
//
//  Why not `isKeyWindow`? If the user opens the dashboard and
//  then clicks another app, the dashboard is still on screen and
//  Grau is still the "owner" of that window — the Dock should
//  still show Grau's icon. `isVisible` is the right signal.
//
//  See docs/HANDOFF.md § 0.4 (app shape: menu bar + window hybrid).
//

import AppKit
import SwiftUI

@MainActor
final class DockIconController {
    /// Wrapper around `NSKeyValueObservation` so we can hold an
    /// array of mixed observation handles and call `invalidate()`
    /// on all of them in `detach()`. The wrapper itself is a no-op
    /// NSObject subclass — we just need an AnyObject to keep the
    /// KVO token alive.
    private final class ObservationToken: NSObject {
        let raw: NSKeyValueObservation
        init(_ raw: NSKeyValueObservation) { self.raw = raw }
    }

    private var observers: [ObservationToken] = []
    private weak var targetWindow: NSWindow?

    /// Attach the controller to a specific NSWindow (the dashboard
    /// "Grau" window). Idempotent — re-attaching to the same window
    /// is a no-op. Safe to call from `.background` of the root view
    /// or from `applicationDidFinishLaunching`.
    func attach(to window: NSWindow) {
        if targetWindow === window { return }
        detach()
        targetWindow = window

        // Seed the policy from the window's current visibility so we
        // don't briefly show the Dock on first open, or hide it on
        // a relaunch where the user dismissed the window before quit.
        applyPolicy(for: window)

        // Watch `isVisible` via KVO. This catches every transition
        // (open, close, hide via -orderOut:, unhide) without us
        // having to subscribe to a bunch of separate notifications.
        // `NSWindow.isVisible` is documented as KVO-observable.
        let observation = window.observe(
            \.isVisible,
            options: [.new, .initial]
        ) { [weak self] window, _ in
            MainActor.assumeIsolated {
                self?.applyPolicy(for: window)
            }
        }
        observers.append(ObservationToken(observation))
    }

    /// Detach all observers. Called on app termination or when the
    /// controller is re-attached to a different window.
    func detach() {
        for token in observers { token.raw.invalidate() }
        observers.removeAll()
        targetWindow = nil
    }

    private func applyPolicy(for window: NSWindow) {
        let desired: NSApplication.ActivationPolicy = window.isVisible ? .regular : .accessory
        if NSApp.activationPolicy() != desired {
            NSApp.setActivationPolicy(desired)
        }
    }

    deinit {
        // Invalidate all KVO tokens on dealloc. NSKeyValueObservation
        // would also stop on its own dealloc, but we want prompt
        // teardown so the closure doesn't fire after the controller
        // is gone (the closure captures `self` weakly, so even a
        // late fire would be a no-op — but better to be explicit).
        for token in observers { token.raw.invalidate() }
    }
}

/// SwiftUI bridge — installs a `DockIconController` for the
/// hosting window on first appearance and tears it down on
/// disappear. Place this as a `.background()` modifier on the
/// root view of the dashboard window.
private struct DockIconBinding: NSViewRepresentable {
    /// Box keeps the controller alive across SwiftUI re-creations
    /// of the `NSViewRepresentable` struct. Without it, every
    /// `updateNSView` would build a fresh controller and drop the
    /// previous observers.
    ///
    /// We mark the controller `lazy` so the Box itself can be
    /// constructed in a non-isolated context (the default-value
    /// expression of `@State`). The lazy initializer then runs the
    /// first time `controller` is touched on the main actor, which
    /// is always inside `makeNSView` / `updateNSView` — both of
    /// which SwiftUI calls on the main actor.
    final class Box {
        @MainActor lazy var controller: DockIconController = DockIconController()
    }
    @State private var box = Box()

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // Defer to the next runloop tick: when `makeNSView` runs,
        // the NSView is not yet in a window. After AppKit attaches
        // it to its host window, `view.window` becomes non-nil.
        DispatchQueue.main.async { [box] in
            if let window = view.window {
                box.controller.attach(to: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // If SwiftUI re-renders (state change, parent recomposition)
        // and the hosting window has changed, re-attach.
        if let window = nsView.window {
            box.controller.attach(to: window)
        }
    }
}

extension View {
    /// Toggles the Dock icon based on the visibility of the
    /// window this view is hosted in. See `DockIconController`.
    func syncDockIconWithWindowVisibility() -> some View {
        background(DockIconBinding())
    }
}
