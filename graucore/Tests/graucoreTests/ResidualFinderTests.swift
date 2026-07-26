//
//  ResidualFinderTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class ResidualFinderTests: XCTestCase {

    /// We override the home directory via a custom finder
    /// implementation. For these tests, we use the real home but
    /// create + tear down our own fake app's residuals.

    var tempHome: URL!
    var fakeApp: InstalledApp!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-residuals-\(UUID().uuidString)", isDirectory: true)
        let library = tempHome.appendingPathComponent("Library", isDirectory: true)
        // Create directories matching the residual paths
        try FileManager.default.createDirectory(
            at: library.appendingPathComponent("Preferences", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: library.appendingPathComponent("Caches/com.example.FakeApp"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: library.appendingPathComponent("Application Support/com.example.FakeApp"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: library.appendingPathComponent("Logs/com.example.FakeApp"),
            withIntermediateDirectories: true
        )
        // Files
        try Data("prefs".utf8).write(
            to: library.appendingPathComponent("Preferences/com.example.FakeApp.plist")
        )
        // Some content in the caches dir
        try Data(repeating: 0, count: 1000).write(
            to: library.appendingPathComponent("Caches/com.example.FakeApp/cache.dat")
        )
        try Data(repeating: 0, count: 2000).write(
            to: library.appendingPathComponent("Application Support/com.example.FakeApp/data.db")
        )

        fakeApp = InstalledApp(
            id: "com.example.FakeApp",
            name: "FakeApp",
            installedVersion: "1.0",
            bundleURL: URL(fileURLWithPath: "/Applications/FakeApp.app"),
            groupContainerIDs: []
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempHome)
        try super.tearDownWithError()
    }

    /// The ResidualFinder uses NSHomeDirectory() internally, so we
    /// can't easily redirect to tempHome. The tests below verify
    /// the candidate-path logic and the kinds mapping by reading
    /// the public API.
    func test_residualKind_displayNames() {
        XCTAssertEqual(ResidualKind.preferences.displayName, "Preferences")
        XCTAssertEqual(ResidualKind.caches.displayName, "Caches")
        XCTAssertEqual(ResidualKind.appSupport.displayName, "Application Support")
        XCTAssertEqual(ResidualKind.containers.displayName, "Containers")
    }

    func test_residualKind_mayContainUserData() {
        XCTAssertTrue(ResidualKind.appSupport.mayContainUserData)
        XCTAssertTrue(ResidualKind.containers.mayContainUserData)
        XCTAssertFalse(ResidualKind.caches.mayContainUserData)
        XCTAssertFalse(ResidualKind.logs.mayContainUserData)
    }

    func test_residualKind_defaultSelected() {
        XCTAssertTrue(ResidualKind.caches.defaultSelected)
        XCTAssertTrue(ResidualKind.logs.defaultSelected)
        XCTAssertFalse(ResidualKind.containers.defaultSelected)
        XCTAssertFalse(ResidualKind.groupContainers.defaultSelected)
    }

    func test_installedApp_idForPathFallback() {
        let app = InstalledApp(
            id: "grau.path.\(URL(fileURLWithPath: "/Applications/X.app").path.hashValue)",
            name: "X",
            installedVersion: "1.0",
            bundleURL: URL(fileURLWithPath: "/Applications/X.app")
        )
        XCTAssertFalse(app.isAppleSystemComponent)
    }
}
