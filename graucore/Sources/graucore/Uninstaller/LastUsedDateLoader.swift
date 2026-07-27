//
//  LastUsedDateLoader.swift
//  graucore
//
//  Looks up Spotlight's `kMDItemLastUsedDate` for a bundle on
//  disk. Returns `nil` when Spotlight has no record (the app
//  was never launched, Spotlight is disabled, the index is
//  cold, or the file path is outside the indexed volume).
//
//  The lookup goes through CoreServices' `MDItem` API rather
//  than `NSMetadataQuery` because we already know the URL of
//  the file we care about — `MDItem` is the right tool for a
//  direct attribute fetch and is dramatically cheaper than
//  spinning up a full `NSMetadataQuery` for every app.
//
//  The macOS Sandbox / TCC settings don't gate this read; the
//  data is per-user and comes from the user's own Spotlight
//  index.
//

import Foundation
import CoreServices

public enum LastUsedDateLoader {

    /// Returns Spotlight's `kMDItemLastUsedDate` for the given
    /// file URL, or `nil` if Spotlight has no record.
    public static func lastUsedDate(for url: URL) -> Date? {
        // MDItemCreateWithURL takes CFURL. Bridge through
        // NSURL -> CFURL — both are toll-free.
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else {
            return nil
        }
        guard let attribute = MDItemCopyAttribute(item, kMDItemLastUsedDate) else {
            return nil
        }
        // The attribute comes back as CFDate (a CF type bridged
        // to Foundation `Date`).
        return (attribute as? Date)
    }
}
