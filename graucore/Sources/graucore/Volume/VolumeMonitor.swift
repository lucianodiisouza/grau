//
//  VolumeMonitor.swift
//  graucore
//
//  Discovers mounted volumes via FileManager.mountedVolumeURLs (NOT
//  by walking /Volumes — that's wrong on Apple Silicon multi-volume
//  setups). See docs/REVIEW.md B1.
//

import Foundation

public actor VolumeMonitor {

    public init() {}

    /// Returns all currently-mounted volumes. Re-reads each time;
    /// this is a fast syscall.
    public func currentVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsReadOnlyKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
        ]
        let options: FileManager.VolumeEnumerationOptions = [.skipHiddenVolumes]

        let urls: [URL]
        do {
            urls = try FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: keys,
                options: options
            ) ?? []
        } catch {
            return []
        }

        return urls.compactMap { url -> VolumeInfo? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                return nil
            }
            let name = values.volumeName ?? url.lastPathComponent
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            return VolumeInfo(
                url: url,
                name: name,
                totalBytes: total,
                freeBytes: free,
                isRemovable: values.volumeIsRemovable ?? false,
                isReadOnly: values.volumeIsReadOnly ?? false
            )
        }
        .sorted { $0.url.path < $1.url.path }
    }

    /// Returns the volume that contains `path`. Falls back to the
    /// system root volume if no match.
    public func volume(containing path: URL) -> VolumeInfo? {
        currentVolumes().first { volume in
            path.path.hasPrefix(volume.url.path)
        }
    }
}
