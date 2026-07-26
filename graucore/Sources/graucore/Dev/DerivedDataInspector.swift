//
//  DerivedDataInspector.swift
//  graucore
//
//  Walks ~/Library/Developer/Xcode/DerivedData and reports the
//  size of each per-project cache. Project dirs are named
//  "<ProjectName>-<hash>"; we surface both the on-disk name and
//  the project name (split off the trailing hash).
//

import Foundation

public struct DerivedDataInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The on-disk directory name, e.g. "MyApp-abcdef1234567890".
    public let folderName: String
    /// The project name, e.g. "MyApp" (without the trailing hash).
    public let projectName: String
    public let path: URL
    public let size: ByteSize
    public let lastModified: Date?

    public init(
        id: UUID = UUID(),
        folderName: String,
        projectName: String,
        path: URL,
        size: ByteSize,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.folderName = folderName
        self.projectName = projectName
        self.path = path
        self.size = size
        self.lastModified = lastModified
    }

    /// Splits "<ProjectName>-<hash>" into its two parts. The hash
    /// is a 24-char lowercase alphanumeric token that Xcode uses
    /// to disambiguate multiple builds of the same project.
    public static func splitProjectName(_ folderName: String) -> (project: String, hash: String?) {
        // Match a trailing "-<alphanumeric>" of length >= 8 anchored
        // to the END. Most Xcode hashes are 24 chars but we don't
        // lock to that. The anchor at the end ensures we capture
        // only the trailing hash, not the project name.
        guard let regex = try? NSRegularExpression(pattern: #"^(.*)-([A-Za-z0-9]{8,})$"#),
              let match = regex.firstMatch(
                in: folderName,
                range: NSRange(folderName.startIndex..., in: folderName)
              ),
              match.numberOfRanges == 3,
              let projectRange = Range(match.range(at: 1), in: folderName),
              let hashRange = Range(match.range(at: 2), in: folderName)
        else {
            return (folderName, nil)
        }
        return (String(folderName[projectRange]), String(folderName[hashRange]))
    }
}

public actor DerivedDataInspector {

    public let derivedDataPath: URL

    public init(
        derivedDataPath: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
    ) {
        self.derivedDataPath = derivedDataPath
    }

    /// Returns one entry per project cache. Skips the per-build
    /// `ModuleCache.noindex` and `Index.noindex` directory, since
    /// those are shared across projects and shouldn't be sized
    /// per-project.
    public func listProjects() async -> [DerivedDataInfo] {
        guard FileManager.default.fileExists(atPath: derivedDataPath.path) else { return [] }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: derivedDataPath,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let sizer = DirectorySizer()
        return await withTaskGroup(
            of: DerivedDataInfo.self,
            returning: [DerivedDataInfo].self
        ) { group in
            for dir in contents {
                let folderName = dir.lastPathComponent
                let split = DerivedDataInfo.splitProjectName(folderName)
                let dirURL = dir
                group.addTask {
                    var totalBytes: Int64 = 0
                    for await event in sizer.size(root: dirURL) {
                        if case .completed(_, let size) = event {
                            totalBytes = size.bytes
                        }
                    }
                    let mtime = (try? FileManager.default.attributesOfItem(atPath: dirURL.path)[.modificationDate] as? Date)
                    return DerivedDataInfo(
                        folderName: folderName,
                        projectName: split.project,
                        path: dirURL,
                        size: ByteSize(bytes: totalBytes),
                        lastModified: mtime
                    )
                }
            }
            var results: [DerivedDataInfo] = []
            for await info in group {
                results.append(info)
            }
            return results.sorted { $0.size > $1.size }
        }
    }
}
