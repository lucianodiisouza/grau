//
//  TrashInfoTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class TrashInfoTests: XCTestCase {

    var tempTrash: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempTrash = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-trash-\(UUID().uuidString)/.Trash", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempTrash,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempTrash.deletingLastPathComponent())
        try super.tearDownWithError()
    }

    func test_readEmptyTrash_returnsZero() {
        let reader = TrashInfoReader()
        let info = reader.read(trashPath: tempTrash)
        XCTAssertEqual(info.size, .zero)
        XCTAssertEqual(info.itemCount, 0)
        XCTAssertFalse(info.isCapped)
    }

    func test_readSizesFiles() throws {
        try Data(repeating: 0, count: 1000).write(to: tempTrash.appendingPathComponent("a"))
        try Data(repeating: 0, count: 2000).write(to: tempTrash.appendingPathComponent("b"))

        let reader = TrashInfoReader()
        let info = reader.read(trashPath: tempTrash)
        XCTAssertEqual(info.size.bytes, 3000)
        XCTAssertEqual(info.itemCount, 2)
    }

    func test_read_nonexistentPath_returnsZero() {
        let reader = TrashInfoReader()
        let info = reader.read(
            trashPath: FileManager.default.temporaryDirectory
                .appendingPathComponent("grau-no-such-trash-\(UUID().uuidString)")
        )
        XCTAssertEqual(info.size, .zero)
        XCTAssertEqual(info.itemCount, 0)
    }

    func test_resolveTrashPath_returnsURL() {
        let path = TrashInfoReader.resolveTrashPath()
        XCTAssertTrue(path.path.hasSuffix(".Trash") || path.path.hasSuffix(".Trash/"))
    }
}
