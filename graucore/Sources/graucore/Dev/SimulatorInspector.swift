//
//  SimulatorInspector.swift
//  graucore
//
//  Walks ~/Library/Developer/CoreSimulator and reports each
//  simulator device's size. Skips booted devices.
//

import Foundation

public struct SimulatorInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let deviceID: String
    public let name: String
    public let runtime: String
    public let size: ByteSize
    public let isBooted: Bool

    public init(
        id: UUID = UUID(),
        deviceID: String,
        name: String,
        runtime: String,
        size: ByteSize,
        isBooted: Bool
    ) {
        self.id = id
        self.deviceID = deviceID
        self.name = name
        self.runtime = runtime
        self.size = size
        self.isBooted = isBooted
    }
}

public actor SimulatorInspector {

    public let coreSimulatorPath: URL

    public init(
        coreSimulatorPath: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator", isDirectory: true)
    ) {
        self.coreSimulatorPath = coreSimulatorPath
    }

    /// Returns one entry per simulator device. Skips booted
    /// devices (we don't trash a running simulator).
    public func listDevices() async -> [SimulatorInfo] {
        let devicesDir = coreSimulatorPath.appendingPathComponent("Devices", isDirectory: true)
        guard FileManager.default.fileExists(atPath: devicesDir.path) else { return [] }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: devicesDir, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let sizer = DirectorySizer()
        return await withTaskGroup(
            of: SimulatorInfo.self,
            returning: [SimulatorInfo].self
        ) { group in
            for deviceDir in contents {
                let plistURL = deviceDir.appendingPathComponent("device.plist")
                guard fm.fileExists(atPath: plistURL.path) else { continue }
                let plist = NSDictionary(contentsOf: plistURL) as? [String: Any] ?? [:]
                let deviceID = plist["UDID"] as? String
                    ?? plist["device-identifier"] as? String
                    ?? deviceDir.lastPathComponent
                let name = (plist["name"] as? String) ?? deviceID
                let runtime = (plist["runtime"] as? String) ?? "unknown"
                let isBooted = (plist["state"] as? String) == "Booted"

                group.addTask {
                    var totalBytes: Int64 = 0
                    for await event in sizer.size(root: deviceDir) {
                        if case .completed(_, let size) = event {
                            totalBytes = size.bytes
                        }
                    }
                    return SimulatorInfo(
                        deviceID: deviceID,
                        name: name,
                        runtime: runtime,
                        size: ByteSize(bytes: totalBytes),
                        isBooted: isBooted
                    )
                }
            }
            var results: [SimulatorInfo] = []
            for await sim in group {
                results.append(sim)
            }
            return results.sorted { $0.size > $1.size }
        }
    }
}
