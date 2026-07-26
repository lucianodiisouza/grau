//
//  DiskTreeBuilderTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class DiskTreeBuilderTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-tree-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    func test_topFolders_emptyDir_returnsEmpty() async {
        let builder = DiskTreeBuilder()
        let nodes = await builder.topFolders(at: tempDir)
        XCTAssertEqual(nodes.count, 0)
    }

    func test_topFolders_sortsBySizeDescending() async throws {
        // Create files of varying sizes
        try Data(repeating: 0, count: 100).write(to: tempDir.appendingPathComponent("small.txt"))
        try Data(repeating: 0, count: 1000).write(to: tempDir.appendingPathComponent("big.txt"))
        try Data(repeating: 0, count: 500).write(to: tempDir.appendingPathComponent("medium.txt"))

        let builder = DiskTreeBuilder()
        let nodes = await builder.topFolders(at: tempDir, limit: 10)
        XCTAssertEqual(nodes.count, 3)
        XCTAssertEqual(nodes[0].name, "big.txt")
        XCTAssertEqual(nodes[1].name, "medium.txt")
        XCTAssertEqual(nodes[2].name, "small.txt")
        XCTAssertEqual(nodes[0].size.bytes, 1000)
    }

    func test_topFolders_respectsLimit() async throws {
        for i in 0..<30 {
            try Data(repeating: 0, count: i * 10 + 1).write(
                to: tempDir.appendingPathComponent("file-\(i).txt")
            )
        }
        let builder = DiskTreeBuilder()
        let nodes = await builder.topFolders(at: tempDir, limit: 5)
        XCTAssertEqual(nodes.count, 5)
    }

    func test_size_returnsDirectoryTotal() async throws {
        let sub = tempDir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 100).write(to: sub.appendingPathComponent("a"))
        try Data(repeating: 0, count: 200).write(to: sub.appendingPathComponent("b"))

        let builder = DiskTreeBuilder()
        let size = await builder.size(of: tempDir)
        XCTAssertEqual(size.bytes, 300)
    }

    func test_diskTreeNode_isLeaf() {
        let leaf = DiskTreeNode(
            url: URL(fileURLWithPath: "/tmp/a"),
            name: "a",
            size: ByteSize(bytes: 100)
        )
        XCTAssertTrue(leaf.isLeaf)

        let withChildren = DiskTreeNode(
            url: URL(fileURLWithPath: "/tmp/dir"),
            name: "dir",
            size: ByteSize(bytes: 1000),
            children: [leaf]
        )
        XCTAssertFalse(withChildren.isLeaf)
    }

    func test_diskTreeNode_sortedChildren() {
        let small = DiskTreeNode(url: URL(fileURLWithPath: "/x"), name: "s", size: ByteSize(bytes: 1))
        let big = DiskTreeNode(url: URL(fileURLWithPath: "/y"), name: "b", size: ByteSize(bytes: 100))
        let parent = DiskTreeNode(
            url: URL(fileURLWithPath: "/p"),
            name: "p",
            size: ByteSize(bytes: 101),
            children: [small, big]
        )
        XCTAssertEqual(parent.sortedChildren.first?.name, "b")
        XCTAssertEqual(parent.sortedChildren.last?.name, "s")
    }
}
