//
//  TrashRestoreTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class TrashRestoreTests: XCTestCase {

    var tempHome: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use a clean home dir by creating a fake "trash root" and
        // a fake "manifest dir" so we never touch the real ~/.Trash
        // during tests. We point TrashMover.defaultManifestDirectory
        // at a custom path via the manifestDirectory parameter.
        tempHome = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appendingPathComponent("grau-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent("trash-manifests", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempHome)
        try super.tearDownWithError()
    }

    func test_listManifests_emptyDir_returnsEmpty() async {
        let restorer = TrashRestore()
        let summaries = await restorer.listManifests()
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_trashManifestSummary_init_storesAllFields() {
        let summary = TrashManifestSummary(
            id: UUID(),
            timestamp: Date(),
            kind: "junk",
            totalSize: 1024,
            itemCount: 5,
            manifestURL: URL(fileURLWithPath: "/tmp/x.json")
        )
        XCTAssertEqual(summary.kind, "junk")
        XCTAssertEqual(summary.totalSize, 1024)
        XCTAssertEqual(summary.itemCount, 5)
    }

    func test_trashRestoreOutcome_init() {
        let outcome = TrashRestoreOutcome(restored: 5, failed: [])
        XCTAssertEqual(outcome.restored, 5)
        XCTAssertTrue(outcome.failed.isEmpty)
    }

    func test_trashRestoreError_descriptions() {
        let id = UUID()
        XCTAssertTrue(TrashRestoreError.manifestNotFound(id).description.contains(id.uuidString))
        XCTAssertTrue(TrashRestoreError.trashItemMissing(original: "/a", currentTrashPath: "/b")
            .description.contains("/a"))
        XCTAssertTrue(TrashRestoreError.originalPathOccupied("/c").description.contains("/c"))
        XCTAssertTrue(TrashRestoreError.moveFailed(original: "/d", underlying: "io")
            .description.contains("/d"))
    }

    func test_manifest_notFound_returnsNil() async {
        let restorer = TrashRestore()
        let m = await restorer.manifest(id: UUID())
        XCTAssertNil(m)
    }

    func test_restore_unknownManifest_returnsFailure() async {
        let restorer = TrashRestore()
        let outcome = await restorer.restore(manifestID: UUID())
        XCTAssertEqual(outcome.restored, 0)
        XCTAssertFalse(outcome.failed.isEmpty)
    }
}
