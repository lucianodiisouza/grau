//
//  PermissionChecker.swift
//  graucore
//
//  Heuristic check for Full Disk Access. We probe a path that
//  requires FDA (the TCC system database) and see if we can read it.
//  See docs/PERMISSIONS.md § 2.4.
//

import Foundation

public actor PermissionChecker {

    public init() {}

    /// The path used to probe FDA state. It must be a path that the
    /// OS hides from non-FDA apps. The TCC database is the standard
    /// choice.
    public static let fdaProbePath = "/Library/Application Support/com.apple.TCC"

    /// Returns `true` if the current process has Full Disk Access.
    /// Heuristic: can we list the contents of `fdaProbePath`?
    public func hasFullDiskAccess() -> Bool {
        let path = Self.fdaProbePath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
              isDir.boolValue else {
            // Path doesn't exist or isn't a directory. We can't tell
            // FDA state from this. Be conservative: return false so
            // the user is prompted.
            return false
        }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: nil
            )
            // If the directory is empty OR the listing is denied (a
            // non-empty contents with all redacted items is also a
            // sign of no-FDA), return false.
            return !contents.isEmpty
        } catch {
            // EACCES or EPERM → no FDA.
            return false
        }
    }

    /// Returns the current permission state. Currently just FDA; the
    /// other permissions are checked via the OS (UNUserNotificationCenter,
    /// etc.) in the app target.
    public func currentState() -> PermissionState {
        PermissionState(
            fullDiskAccess: hasFullDiskAccess(),
            notifications: .notRequested,
            appleEventsPromptedForFinder: false
        )
    }
}
