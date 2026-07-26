//
//  NodeModulesFinderTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class NodeModulesFinderTests: XCTestCase {

    var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let raw = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-nm-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        // The scanner returns resolved paths (e.g. /private/var/...).
        // Re-read the canonical URL after creating the dir so both
        // sides of the comparison agree.
        tempRoot = raw.resolvingSymlinksInPath().standardizedFileURL
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeProject(
        at dir: URL,
        nmFiles: [(String, Int)]
    ) throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let nm = dir.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: nm, withIntermediateDirectories: true)
        for (name, size) in nmFiles {
            try Data(repeating: 0, count: size).write(to: nm.appendingPathComponent(name))
        }
        return nm
    }

    func test_defaultUserRoots_containsHome() {
        let roots = NodeModulesFinder.defaultUserRoots()
        XCTAssertFalse(roots.isEmpty)
        XCTAssertEqual(roots[0], FileManager.default.homeDirectoryForCurrentUser)
    }

    func test_init_storesProvidedRoots() async {
        let finder = NodeModulesFinder(defaultRoots: [tempRoot])
        XCTAssertEqual(finder.defaultRoots, [tempRoot])
    }

    func test_find_singleProject() async throws {
        let projectA = tempRoot.appendingPathComponent("projectA", isDirectory: true)
        let nmA = try makeProject(at: projectA, nmFiles: [("a.js", 100), ("b.js", 200)])

        let finder = NodeModulesFinder(defaultRoots: [tempRoot])
        let results = await finder.find()

        XCTAssertEqual(results.count, 1)
        // The scanner resolves /var → /private/var so compare via
        // the last two path components instead of the full path.
        let resultComponents = results[0].path.pathComponents.suffix(2)
        let nmComponents = nmA.pathComponents.suffix(2)
        XCTAssertEqual(Array(resultComponents), Array(nmComponents))
        let rootComponents = results[0].projectRoot.pathComponents.suffix(2)
        let projComponents = projectA.pathComponents.suffix(2)
        XCTAssertEqual(Array(rootComponents), Array(projComponents))
        XCTAssertEqual(results[0].size.bytes, 300)
    }

    func test_find_multipleProjects() async throws {
        for i in 0..<3 {
            let p = tempRoot.appendingPathComponent("project\(i)", isDirectory: true)
            try makeProject(at: p, nmFiles: [("x.js", 10 * (i + 1))])
        }

        let finder = NodeModulesFinder(defaultRoots: [tempRoot])
        let results = await finder.find()
        XCTAssertEqual(results.count, 3)
    }

    func test_find_doesNotRecurseIntoNodeModules() async throws {
        // If we have root/proj/node_modules/deep/inner, the
        // inner should not be found.
        let project = tempRoot.appendingPathComponent("proj", isDirectory: true)
        let nm = try makeProject(at: project, nmFiles: [])
        let deep = nm.appendingPathComponent("deep", isDirectory: true)
        let inner = deep.appendingPathComponent("inner", isDirectory: true)
        try FileManager.default.createDirectory(
            at: deep.appendingPathComponent("node_modules", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)

        let finder = NodeModulesFinder(defaultRoots: [tempRoot])
        let results = await finder.find()
        XCTAssertEqual(results.count, 1, "Should not recurse into node_modules")
        let resultComponents = results[0].path.pathComponents.suffix(2)
        let nmComponents = nm.pathComponents.suffix(2)
        XCTAssertEqual(Array(resultComponents), Array(nmComponents))
    }

    func test_find_nestedProjectBelowMaxDepth() async throws {
        let deep = tempRoot
            .appendingPathComponent("a", isDirectory: true)
            .appendingPathComponent("b", isDirectory: true)
            .appendingPathComponent("c", isDirectory: true)
            .appendingPathComponent("d", isDirectory: true)
            .appendingPathComponent("e", isDirectory: true)
        try makeProject(at: deep, nmFiles: [("f.js", 50)])

        let finder = NodeModulesFinder(defaultRoots: [tempRoot])
        let results = await finder.find(maxDepth: 10)
        XCTAssertEqual(results.count, 1)
    }

    func test_find_respectsMaxDepth() async throws {
        let deep = tempRoot
            .appendingPathComponent("a", isDirectory: true)
            .appendingPathComponent("b", isDirectory: true)
            .appendingPathComponent("c", isDirectory: true)
            .appendingPathComponent("d", isDirectory: true)
            .appendingPathComponent("e", isDirectory: true)
        try makeProject(at: deep, nmFiles: [("f.js", 50)])

        let finder = NodeModulesFinder(defaultRoots: [tempRoot])
        let results = await finder.find(maxDepth: 2)
        XCTAssertEqual(results.count, 0, "Should be filtered by maxDepth")
    }

    func test_find_resultsSortedBySizeDescending() async throws {
        try makeProject(at: tempRoot.appendingPathComponent("small", isDirectory: true),
                        nmFiles: [("s.js", 1)])
        try makeProject(at: tempRoot.appendingPathComponent("big", isDirectory: true),
                        nmFiles: [("b.js", 9_999)])

        let finder = NodeModulesFinder(defaultRoots: [tempRoot])
        let results = await finder.find()
        XCTAssertEqual(results.count, 2)
        XCTAssertGreaterThanOrEqual(results[0].size, results[1].size)
    }

    func test_find_emptyRoot_returnsEmpty() async {
        let raw = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-nm-empty-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: raw) }

        let finder = NodeModulesFinder(defaultRoots: [raw])
        let results = await finder.find()
        XCTAssertTrue(results.isEmpty)
    }
}
