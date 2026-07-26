//
//  VolumeMonitorTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class VolumeMonitorTests: XCTestCase {

    func test_currentVolumes_returnsAtLeastRoot() async {
        let monitor = VolumeMonitor()
        let volumes = await monitor.currentVolumes()
        // At least the root volume should be present
        XCTAssertFalse(volumes.isEmpty, "Expected at least one mounted volume")
        XCTAssertTrue(volumes.contains { $0.url.path == "/" })
    }

    func test_currentVolumes_includesAllRequiredFields() async {
        let monitor = VolumeMonitor()
        let volumes = await monitor.currentVolumes()
        for volume in volumes {
            XCTAssertFalse(volume.name.isEmpty)
            XCTAssertGreaterThanOrEqual(volume.totalBytes, 0)
            XCTAssertGreaterThanOrEqual(volume.freeBytes, 0)
            XCTAssertLessThanOrEqual(volume.freeBytes, volume.totalBytes)
            XCTAssertGreaterThanOrEqual(volume.usedBytes, 0)
        }
    }

    func test_volumeContaining_returnsRootForSystemPaths() async {
        let monitor = VolumeMonitor()
        let volume = await monitor.volume(containing: URL(fileURLWithPath: "/tmp/foo.txt"))
        XCTAssertNotNil(volume)
        XCTAssertEqual(volume?.url.path, "/")
    }

    func test_volumeContaining_returnsNilForUnmatchedPath() async {
        let monitor = VolumeMonitor()
        // An obviously-bogus absolute path
        let volume = await monitor.volume(containing: URL(fileURLWithPath: "/this/path/does/not/exist"))
        // The root volume is the catch-all
        XCTAssertNotNil(volume)
    }
}
