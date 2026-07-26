//
//  DockerInspectorTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class DockerInspectorTests: XCTestCase {

    func test_dockerInfo_equality() {
        let a = DockerInfo(dockerInstalled: true, buildCacheSize: ByteSize(bytes: 100))
        let b = DockerInfo(dockerInstalled: true, buildCacheSize: ByteSize(bytes: 100))
        XCTAssertEqual(a, b)
    }

    func test_dockerNotInstalled_hasDockerInstalledFalse() {
        XCTAssertFalse(DockerInfo.dockerNotInstalled.dockerInstalled)
    }

    func test_dockerDaemonDown_hasDockerInstalledTrue_butAllZeros() {
        let info = DockerInfo.dockerDaemonDown
        XCTAssertTrue(info.dockerInstalled)
        XCTAssertEqual(info.stoppedContainers, 0)
        XCTAssertEqual(info.danglingImages, 0)
        XCTAssertEqual(info.unusedVolumes, 0)
        XCTAssertEqual(info.buildCacheSize, .zero)
        XCTAssertEqual(info.reclaimable, .zero)
    }

    func test_parseSize_bytes() {
        XCTAssertEqual(DockerInspector.parseSize("100B")?.bytes, 100)
    }

    func test_parseSize_kilobytes() {
        XCTAssertEqual(DockerInspector.parseSize("5KB")?.bytes, 5_000)
    }

    func test_parseSize_megabytes() {
        XCTAssertEqual(DockerInspector.parseSize("10MB")?.bytes, 10_000_000)
    }

    func test_parseSize_gigabytes() {
        XCTAssertEqual(DockerInspector.parseSize("1.5GB")?.bytes, 1_500_000_000)
    }

    func test_parseSize_terabytes() {
        XCTAssertEqual(DockerInspector.parseSize("2TB")?.bytes, 2_000_000_000_000)
    }

    func test_parseSize_lowercase_units() {
        // Docker emits uppercase but make sure we're defensive
        XCTAssertEqual(DockerInspector.parseSize("1gb")?.bytes, 1_000_000_000)
    }

    func test_parseSize_invalid_returnsNil() {
        XCTAssertNil(DockerInspector.parseSize(""))
        XCTAssertNil(DockerInspector.parseSize("abc"))
        XCTAssertNil(DockerInspector.parseSize("1XB"))
    }

    func test_parseOutput_buildCacheRow() {
        // Realistic `docker system df -v` first few lines
        let output = """
        TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
        Images          5         1         1.234GB   500MB (40%)
        Containers      2         0         0B        0B
        Local Volumes   1         1         100MB     0B
        Build Cache     10        0         2.5GB     2.0GB
        """
        let info = DockerInspector.parseOutput(output)
        XCTAssertTrue(info.dockerInstalled)
        XCTAssertEqual(info.buildCacheSize.bytes, 2_500_000_000)
        XCTAssertEqual(info.reclaimable.bytes, 2_000_000_000)
    }

    func test_parseOutput_emptyOutput_yieldsZeros() {
        let info = DockerInspector.parseOutput("")
        XCTAssertTrue(info.dockerInstalled)
        XCTAssertEqual(info.buildCacheSize, .zero)
        XCTAssertEqual(info.reclaimable, .zero)
    }
}
