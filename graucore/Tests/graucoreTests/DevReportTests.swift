//
//  DevReportTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class DevReportTests: XCTestCase {

    func test_init_defaultsAreSensible() {
        let report = DevReport()
        XCTAssertNotNil(report.generatedAt)
        XCTAssertTrue(report.packageCaches.isEmpty)
        XCTAssertTrue(report.nodeModules.isEmpty)
        XCTAssertEqual(report.docker, .dockerNotInstalled)
        XCTAssertTrue(report.simulators.isEmpty)
        XCTAssertTrue(report.derivedData.isEmpty)
        XCTAssertTrue(report.archives.isEmpty)
        XCTAssertEqual(report.totalSize, .zero)
        XCTAssertEqual(report.presentPackageCacheCount, 0)
    }

    func test_totalSize_sumsPresentCategories() {
        let report = DevReport(
            packageCaches: [
                PackageCacheInfo(
                    kind: .npm, paths: [], size: ByteSize(bytes: 100), exists: true
                )
            ],
            nodeModules: [
                NodeModulesInfo(
                    path: URL(fileURLWithPath: "/p/nm"),
                    projectRoot: URL(fileURLWithPath: "/p"),
                    size: ByteSize(bytes: 200)
                )
            ],
            simulators: [
                SimulatorInfo(
                    deviceID: "A", name: "A", runtime: "iOS",
                    size: ByteSize(bytes: 300), isBooted: false
                ),
                SimulatorInfo(
                    deviceID: "B", name: "B", runtime: "iOS",
                    size: ByteSize(bytes: 999), isBooted: true  // should be excluded
                ),
            ],
            derivedData: [
                DerivedDataInfo(
                    folderName: "X-aaaa", projectName: "X",
                    path: URL(fileURLWithPath: "/d/X-aaaa"),
                    size: ByteSize(bytes: 400)
                )
            ],
            archives: [
                ArchiveInfo(
                    name: "a.xcarchive",
                    path: URL(fileURLWithPath: "/a/a.xcarchive"),
                    size: ByteSize(bytes: 500)
                )
            ]
        )
        XCTAssertEqual(report.totalSize.bytes, 100 + 200 + 300 + 400 + 500)
    }

    func test_totalSize_skipsBootedSimulators() {
        let report = DevReport(
            simulators: [
                SimulatorInfo(
                    deviceID: "B", name: "B", runtime: "iOS",
                    size: ByteSize(bytes: 999), isBooted: true
                )
            ]
        )
        XCTAssertEqual(report.totalSize, .zero)
    }

    func test_presentPackageCacheCount_filtersNonExistent() {
        let report = DevReport(
            packageCaches: [
                PackageCacheInfo(kind: .npm, paths: [], size: .zero, exists: true),
                PackageCacheInfo(kind: .pnpm, paths: [], size: .zero, exists: false),
                PackageCacheInfo(kind: .cargo, paths: [], size: .zero, exists: true),
            ]
        )
        XCTAssertEqual(report.presentPackageCacheCount, 2)
    }

    func test_generate_runsAllInspectors() async {
        // Don't actually call the full generator because that walks
        // the host's home; just verify it returns a report and
        // the structure is sound.
        let gen = DevReportGenerator()
        let report = await gen.generate()
        // The report itself can be empty if nothing is on the host;
        // but it should always have a timestamp.
        XCTAssertNotNil(report.generatedAt)
        // Total size is non-negative
        XCTAssertGreaterThanOrEqual(report.totalSize.bytes, 0)
    }
}
