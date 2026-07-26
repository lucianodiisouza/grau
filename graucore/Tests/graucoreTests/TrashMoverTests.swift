//
//  TrashMoverTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class TrashMoverTests: XCTestCase {

    var tempDir: URL!
    var manifestDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-trash-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manifestDir = tempDir.appendingPathComponent("manifests", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    func test_trash_singleFile_movesToTrashAndWritesManifest() async throws {
        let file = tempDir.appendingPathComponent("victim.txt")
        try Data("data".utf8).write(to: file)

        let mover = TrashMover()
        let manifest = try await mover.trash(
            items: [file],
            kind: "test",
            manifestDirectory: manifestDir
        )

        XCTAssertEqual(manifest.kind, "test")
        XCTAssertEqual(manifest.items.count, 1)
        XCTAssertEqual(manifest.items[0].originalPath, file.path)
        XCTAssertGreaterThan(manifest.totalSize, 0)

        // The file should be gone from the source
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        // The manifest should be on disk
        let manifests = try FileManager.default.contentsOfDirectory(at: manifestDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(manifests.count, 1)
    }

    func test_trash_multipleItems_aggregatesManifest() async throws {
        let f1 = tempDir.appendingPathComponent("a.txt")
        let f2 = tempDir.appendingPathComponent("b.txt")
        try Data("aaa".utf8).write(to: f1)
        try Data("bbbb".utf8).write(to: f2)

        let mover = TrashMover()
        let manifest = try await mover.trash(
            items: [f1, f2],
            kind: "test",
            manifestDirectory: manifestDir
        )

        XCTAssertEqual(manifest.items.count, 2)
        XCTAssertEqual(manifest.totalSize, 7)  // 3 + 4
    }

    func test_trash_emptyArray_writesEmptyManifest() async throws {
        let mover = TrashMover()
        let manifest = try await mover.trash(
            items: [],
            kind: "empty",
            manifestDirectory: manifestDir
        )
        XCTAssertEqual(manifest.items.count, 0)
        XCTAssertEqual(manifest.totalSize, 0)
    }

    func test_trash_missingFile_logsButContinues() async throws {
        let real = tempDir.appendingPathComponent("real.txt")
        try Data("x".utf8).write(to: real)
        let ghost = tempDir.appendingPathComponent("ghost.txt") // never created

        let mover = TrashMover()
        let manifest = try await mover.trash(
            items: [ghost, real],
            kind: "test",
            manifestDirectory: manifestDir
        )

        // Only the real file should be in the manifest
        XCTAssertEqual(manifest.items.count, 1)
        XCTAssertEqual(manifest.items[0].originalPath, real.path)
    }

    func test_trash_createsManifestDirectory_ifMissing() async throws {
        let nested = manifestDir.appendingPathComponent("nested", isDirectory: true)
        let mover = TrashMover()
        let file = tempDir.appendingPathComponent("f.txt")
        try Data("x".utf8).write(to: file)

        _ = try await mover.trash(
            items: [file],
            kind: "test",
            manifestDirectory: nested
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    func test_manifestRoundTripsThroughCodable() throws {
        let item = TrashManifestItem(
            originalPath: "/tmp/x",
            trashRelativePath: "x",
            size: 42
        )
        let manifest = TrashManifest(
            id: UUID(),
            timestamp: Date(),
            kind: "test",
            totalSize: 42,
            items: [item]
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(TrashManifest.self, from: data)
        XCTAssertEqual(manifest, decoded)
    }
}
