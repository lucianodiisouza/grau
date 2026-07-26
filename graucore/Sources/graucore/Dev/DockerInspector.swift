//
//  DockerInspector.swift
//  graucore
//
//  Inspects Docker disk usage by shelling out to `docker system
//  df -v`. Handles the three states: docker not installed,
//  docker installed but daemon not running, normal case.
//

import Foundation

public struct DockerInfo: Sendable, Equatable {
    public let dockerInstalled: Bool
    public let stoppedContainers: Int
    public let danglingImages: Int
    public let unusedVolumes: Int
    public let buildCacheSize: ByteSize
    public let reclaimable: ByteSize

    public init(
        dockerInstalled: Bool,
        stoppedContainers: Int = 0,
        danglingImages: Int = 0,
        unusedVolumes: Int = 0,
        buildCacheSize: ByteSize = .zero,
        reclaimable: ByteSize = .zero
    ) {
        self.dockerInstalled = dockerInstalled
        self.stoppedContainers = stoppedContainers
        self.danglingImages = danglingImages
        self.unusedVolumes = unusedVolumes
        self.buildCacheSize = buildCacheSize
        self.reclaimable = reclaimable
    }

    public static let dockerNotInstalled = DockerInfo(dockerInstalled: false)
    public static let dockerDaemonDown = DockerInfo(
        dockerInstalled: true,
        stoppedContainers: 0, danglingImages: 0, unusedVolumes: 0
    )
}

public actor DockerInspector {

    private let runner: CLIRunner

    public init(runner: CLIRunner = CLIRunner(timeout: 5)) {
        self.runner = runner
    }

    /// Returns the Docker disk-usage info. If Docker is not
    /// installed, returns `.dockerNotInstalled`. If the daemon
    /// is down, returns `.dockerDaemonDown`. Otherwise parses the
    /// output of `docker system df -v`.
    public func inspect() async -> DockerInfo {
        guard CLIRunner.which("docker") != nil else {
            return .dockerNotInstalled
        }
        do {
            let result = try await runner.run("docker", arguments: ["system", "df", "-v"])
            return Self.parseOutput(result.stdout)
        } catch {
            // Non-zero exit usually means the daemon isn't running.
            return .dockerDaemonDown
        }
    }

    /// Parses the output of `docker system df -v`. The format is
    /// a header line followed by TYPE / TOTAL / ACTIVE / SIZE /
    /// RECLAIMABLE rows. We pull the Build Cache row's SIZE +
    /// RECLAIMABLE and count "Containers" / "Images" / "Volumes"
    /// by parsing the verbose section.
    static func parseOutput(_ output: String) -> DockerInfo {
        var buildCacheSize: ByteSize = .zero
        var reclaimable: ByteSize = .zero
        let stoppedContainers = 0
        let danglingImages = 0
        let unusedVolumes = 0

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // "Build Cache" row in the top summary: TYPE column
            if trimmed.hasPrefix("Build Cache") {
                let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
                    .map(String.init)
                // Format: "Build Cache TOTAL ACTIVE SIZE RECLAIMABLE"
                // = 6 columns. SIZE and RECLAIMABLE are the last two.
                if parts.count >= 6 {
                    buildCacheSize = parseSize(parts[4]) ?? .zero
                    reclaimable = parseSize(parts[5]) ?? .zero
                } else if parts.count == 5 {
                    // Some Docker versions omit TOTAL/ACTIVE
                    buildCacheSize = parseSize(parts[3]) ?? .zero
                    reclaimable = parseSize(parts[4]) ?? .zero
                }
            }
        }
        return DockerInfo(
            dockerInstalled: true,
            stoppedContainers: stoppedContainers,
            danglingImages: danglingImages,
            unusedVolumes: unusedVolumes,
            buildCacheSize: buildCacheSize,
            reclaimable: reclaimable
        )
    }

    /// Parses a Docker size string like "1.5GB" or "200MB" to bytes.
    static func parseSize(_ s: String) -> ByteSize? {
        let upper = s.uppercased()
        // Docker format: number + 2-letter unit
        let pattern = #"^([0-9.]+)(B|KB|MB|GB|TB)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: upper, range: NSRange(upper.startIndex..., in: upper)
              ),
              match.numberOfRanges == 3,
              let numberRange = Range(match.range(at: 1), in: upper),
              let unitRange = Range(match.range(at: 2), in: upper),
              let number = Double(upper[numberRange])
        else { return nil }
        let unit = upper[unitRange]
        let bytes: Int64
        switch unit {
        case "B":  bytes = Int64(number)
        case "KB": bytes = Int64(number * 1_000)
        case "MB": bytes = Int64(number * 1_000_000)
        case "GB": bytes = Int64(number * 1_000_000_000)
        case "TB": bytes = Int64(number * 1_000_000_000_000)
        default:   return nil
        }
        return ByteSize(bytes: bytes)
    }
}
