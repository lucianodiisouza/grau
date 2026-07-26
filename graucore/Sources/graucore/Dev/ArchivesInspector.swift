//
//  ArchivesInspector.swift
//  graucore
//
//  Walks ~/Library/Developer/Xcode/Archives and reports each
//  .xcarchive bundle's size. Archives are essential for shipping
//  and must never be deleted by default — Grau's Dev mode
//  surfaces them behind a `userCaution` gate (default OFF).
//

import Foundation

public struct ArchiveInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let size: ByteSize
    public let date: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        size: ByteSize,
        date: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.date = date
    }
}

public actor ArchivesInspector {

    public let archivesPath: URL

    public init(
        archivesPath: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true)
    ) {
        self.archivesPath = archivesPath
    }

    /// Returns one entry per .xcarchive bundle. Each archive lives
    /// in a per-date subdirectory ("2026-07-26") so the typical
    /// result is a flat list of bundles across dates.
    public func listArchives() async -> [ArchiveInfo] {
        guard FileManager.default.fileExists(atPath: archivesPath.path) else { return [] }
        let fm = FileManager.default
        guard let dateDirs = try? fm.contentsOfDirectory(
            at: archivesPath,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let sizer = DirectorySizer()
        return await withTaskGroup(
            of: ArchiveInfo.self,
            returning: [ArchiveInfo].self
        ) { group in
            for dateDir in dateDirs {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dateDir.path, isDirectory: &isDir),
                      isDir.boolValue else { continue }
                guard let archives = try? fm.contentsOfDirectory(
                    at: dateDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for archive in archives where archive.pathExtension == "xcarchive" {
                    let archiveURL = archive
                    group.addTask {
                        var totalBytes: Int64 = 0
                        for await event in sizer.size(root: archiveURL) {
                            if case .completed(_, let size) = event {
                                totalBytes = size.bytes
                            }
                        }
                        let mtime = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.modificationDate] as? Date)
                        return ArchiveInfo(
                            name: archiveURL.lastPathComponent,
                            path: archiveURL,
                            size: ByteSize(bytes: totalBytes),
                            date: mtime
                        )
                    }
                }
            }
            var results: [ArchiveInfo] = []
            for await info in group {
                results.append(info)
            }
            return results.sorted { $0.size > $1.size }
        }
    }
}
