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

    func test_scan_bundleSize_defaultsToZero() async throws {
        try makeFakeApp(
            at: tempDir.appendingPathComponent("TinyApp.app"),
            plist: [
                "CFBundleIdentifier": "com.example.TinyApp",
                "CFBundleDisplayName": "Tiny",
                "CFBundleShortVersionString": "1.0",
            ]
        )
        let scanner = AppScanner(searchPaths: [tempDir])
        let apps = await scanner.scan()
        XCTAssertEqual(apps.count, 1)
        // scan() returns quickly; the size is filled in by a later
        // pass (see computeBundleSize), not synchronously.
        XCTAssertEqual(apps.first?.bundleSize, 0)
    }

    func test_scan_withSizes_populatesBundleSize() async throws {
        let appURL = tempDir.appendingPathComponent("SizedApp.app")
        try makeFakeApp(
            at: appURL,
            plist: [
                "CFBundleIdentifier": "com.example.SizedApp",
                "CFBundleDisplayName": "Sized",
                "CFBundleShortVersionString": "1.0",
            ]
        )
        // Drop 5 KB of payload inside the bundle so computeBundleSize
        // has something concrete to count.
        let payload = Data(repeating: 0x42, count: 5_000)
        try payload.write(
            to: appURL.appendingPathComponent("Contents/payload.bin")
        )

        let scanner = AppScanner(searchPaths: [tempDir])
        let apps = await scanner.scan(withSizes: ())
        XCTAssertEqual(apps.count, 1)
        let size = apps.first?.bundleSize ?? 0
        XCTAssertGreaterThanOrEqual(size, 5_000,
            "bundleSize should be at least the size of the payload we wrote")
    }

    func test_computeBundleSize_returnsZeroForMissingBundle() {
        let ghost = tempDir.appendingPathComponent("DoesNotExist.app")
        XCTAssertEqual(AppScanner.computeBundleSize(at: ghost), 0)
    }

    func test_computeBundleSize_countsAllFilesInBundle() throws {
        let appURL = tempDir.appendingPathComponent("CountedApp.app")
        try makeFakeApp(
            at: appURL,
            plist: [
                "CFBundleIdentifier": "com.example.CountedApp",
                "CFBundleDisplayName": "Counted",
                "CFBundleShortVersionString": "1.0",
            ]
        )
        // Two files of known size, in nested subdirectories. Create
        // the Resources directory first since Data.write doesn't
        // create intermediate paths.
        try FileManager.default.createDirectory(
            at: appURL.appendingPathComponent("Contents/Resources"),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x1, count: 1_000).write(
            to: appURL.appendingPathComponent("Contents/a.bin")
        )
        try Data(repeating: 0x2, count: 2_500).write(
            to: appURL.appendingPathComponent("Contents/Resources/b.bin")
        )
        let size = AppScanner.computeBundleSize(at: appURL)
        XCTAssertGreaterThanOrEqual(size, 3_500)
    }
}
