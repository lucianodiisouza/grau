//
//  AppScannerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class AppScannerTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-apps-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    /// Builds a fake .app bundle at `path` with the given plist contents.
    private func makeFakeApp(
        at path: URL,
        plist: [String: Any],
        includeUninstallHelper: Bool = false
    ) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: path, withIntermediateDirectories: true)
        try fm.createDirectory(at: path.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: path.appendingPathComponent("Contents/Info.plist"))
        if includeUninstallHelper {
            try fm.createDirectory(
                at: path.appendingPathComponent("Contents/Resources/Uninstall.app"),
                withIntermediateDirectories: true
            )
        }
    }

    func test_scan_emptyDir_returnsEmpty() async {
        let scanner = AppScanner(searchPaths: [tempDir])
        let apps = await scanner.scan()
        XCTAssertEqual(apps.count, 0)
    }

    func test_scan_findsBundlesWithValidInfoPlist() async throws {
        try makeFakeApp(
            at: tempDir.appendingPathComponent("TestApp.app"),
            plist: [
                "CFBundleIdentifier": "com.example.TestApp",
                "CFBundleDisplayName": "Test App",
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
            ]
        )
        let scanner = AppScanner(searchPaths: [tempDir])
        let apps = await scanner.scan()
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.name, "Test App")
        XCTAssertEqual(apps.first?.id, "com.example.TestApp")
        XCTAssertEqual(apps.first?.installedVersion, "1.0.0")
    }

    func test_scan_detectsUninstallHelper() async throws {
        try makeFakeApp(
            at: tempDir.appendingPathComponent("HelperApp.app"),
            plist: [
                "CFBundleIdentifier": "com.example.HelperApp",
                "CFBundleName": "HelperApp",
                "CFBundleShortVersionString": "1.0",
            ],
            includeUninstallHelper: true
        )
        let scanner = AppScanner(searchPaths: [tempDir])
        let apps = await scanner.scan()
        XCTAssertEqual(apps.count, 1)
        XCTAssertTrue(apps.first?.hasUninstallHelper ?? false)
        XCTAssertNotNil(apps.first?.helperPath)
    }

    func test_scan_readsGroupContainerEntitlements() async throws {
        // Note: entitlements are typically in a separate .entitlements
        // file, but we read them from Info.plist for simplicity.
        // The AppScanner uses BundleMetadataLoader which looks at
        // com.apple.security.application-groups in the plist.
        try makeFakeApp(
            at: tempDir.appendingPathComponent("GroupApp.app"),
            plist: [
                "CFBundleIdentifier": "com.example.GroupApp",
                "CFBundleName": "GroupApp",
                "CFBundleShortVersionString": "1.0",
                "com.apple.security.application-groups": [
                    "group.com.example.shared"
                ],
            ]
        )
        let scanner = AppScanner(searchPaths: [tempDir])
        let apps = await scanner.scan()
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.groupContainerIDs, ["group.com.example.shared"])
    }

    func test_installedApp_isAppleSystemComponent() {
        let app = InstalledApp(
            id: "com.apple.Safari",
            name: "Safari",
            installedVersion: "1.0",
            bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")
        )
        XCTAssertTrue(app.isAppleSystemComponent)
    }
}
