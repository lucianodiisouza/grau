//
//  DevReport.swift
//  graucore
//
//  Aggregates the six Dev-mode inspectors into a single report.
//  Runs them in parallel so the user sees the whole picture
//  without sequential waits.
//

import Foundation

public struct DevReport: Sendable {
    public let generatedAt: Date
    public let packageCaches: [PackageCacheInfo]
    public let nodeModules: [NodeModulesInfo]
    public let docker: DockerInfo
    public let simulators: [SimulatorInfo]
    public let derivedData: [DerivedDataInfo]
    public let archives: [ArchiveInfo]

    public init(
        generatedAt: Date = Date(),
        packageCaches: [PackageCacheInfo] = [],
        nodeModules: [NodeModulesInfo] = [],
        docker: DockerInfo = .dockerNotInstalled,
        simulators: [SimulatorInfo] = [],
        derivedData: [DerivedDataInfo] = [],
        archives: [ArchiveInfo] = []
    ) {
        self.generatedAt = generatedAt
        self.packageCaches = packageCaches
        self.nodeModules = nodeModules
        self.docker = docker
        self.simulators = simulators
        self.derivedData = derivedData
        self.archives = archives
    }

    /// The total size of every category combined (only the
    /// filesystem-based ones — docker is reported as
    /// `reclaimable` so it's harder to attribute).
    public var totalSize: ByteSize {
        let caches = packageCaches.reduce(ByteSize.zero) { $0 + $1.size }
        let node = nodeModules.reduce(ByteSize.zero) { $0 + $1.size }
        let sims = simulators
            .filter { !$0.isBooted }
            .reduce(ByteSize.zero) { $0 + $1.size }
        let dd = derivedData.reduce(ByteSize.zero) { $0 + $1.size }
        let arch = archives.reduce(ByteSize.zero) { $0 + $1.size }
        return caches + node + sims + dd + arch
    }

    /// Convenience: the number of package caches actually present
    /// on the host (skip ones where `exists == false`).
    public var presentPackageCacheCount: Int {
        packageCaches.filter { $0.exists }.count
    }
}

public actor DevReportGenerator {

    public init() {}

    /// Runs all six inspectors in parallel and returns a
    /// `DevReport`. Each inspector is independent, so we can
    /// `await` all six concurrently.
    public func generate() async -> DevReport {
        async let caches = PackageCacheScanner().scan()
        async let nodes = NodeModulesFinder().find()
        async let docker = DockerInspector().inspect()
        async let sims = SimulatorInspector().listDevices()
        async let dd = DerivedDataInspector().listProjects()
        async let arch = ArchivesInspector().listArchives()

        return await DevReport(
            packageCaches: caches,
            nodeModules: nodes,
            docker: docker,
            simulators: sims,
            derivedData: dd,
            archives: arch
        )
    }
}
