//
//  SimulatorInspectorTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class SimulatorInspectorTests: XCTestCase {

    var fakeCoreSim: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fakeCoreSim = FileManager.default.temporaryDirectory
            .appendingPathComponent("grau-coresim-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: fakeCoreSim.appendingPathComponent("Devices", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fakeCoreSim)
        try super.tearDownWithError()
    }

    private func makeDevice(
        named name: String,
        udid: String,
        runtime: String,
        state: String,
        fileCount: Int = 1
    ) throws -> URL {
        let dir = fakeCoreSim
            .appendingPathComponent("Devices", isDirectory: true)
            .appendingPathComponent(udid, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "UDID": udid,
            "name": name,
            "runtime": runtime,
            "state": state,
        ]
        let plistURL = dir.appendingPathComponent("device.plist")
        (plist as NSDictionary).write(to: plistURL, atomically: true)
        for i in 0..<fileCount {
            try Data(repeating: 0, count: 100).write(
                to: dir.appendingPathComponent("data-\(i).bin")
            )
        }
        return dir
    }

    func test_listDevices_missingRoot_returnsEmpty() async {
        let inspector = SimulatorInspector(
            coreSimulatorPath: FileManager.default.temporaryDirectory
                .appendingPathComponent("grau-coresim-missing-\(UUID().uuidString)")
        )
        let results = await inspector.listDevices()
        XCTAssertTrue(results.isEmpty)
    }

    func test_listDevices_emptyDevicesDir_returnsEmpty() async {
        let inspector = SimulatorInspector(coreSimulatorPath: fakeCoreSim)
        let results = await inspector.listDevices()
        XCTAssertTrue(results.isEmpty)
    }

    func test_listDevices_singleDevice() async throws {
        _ = try makeDevice(
            named: "iPhone 15",
            udid: "AAAAAAAA-1111-1111-1111-111111111111",
            runtime: "com.apple.CoreSimulator.SimRuntime.iOS-17-0",
            state: "Shutdown",
            fileCount: 3
        )
        let inspector = SimulatorInspector(coreSimulatorPath: fakeCoreSim)
        let results = await inspector.listDevices()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "iPhone 15")
        XCTAssertEqual(results[0].deviceID, "AAAAAAAA-1111-1111-1111-111111111111")
        XCTAssertEqual(results[0].runtime, "com.apple.CoreSimulator.SimRuntime.iOS-17-0")
        XCTAssertFalse(results[0].isBooted)
        // Size is the total of all files in the device dir,
        // including the device.plist we wrote. We just verify
        // it's at least the 3 * 100 bytes of data files we made.
        XCTAssertGreaterThanOrEqual(results[0].size.bytes, 300)
    }

    func test_listDevices_marksBootedCorrectly() async throws {
        _ = try makeDevice(
            named: "Booted iPhone",
            udid: "B-1111-1111-1111-111111111111",
            runtime: "iOS-17-0",
            state: "Booted"
        )
        _ = try makeDevice(
            named: "Shutdown iPhone",
            udid: "S-1111-1111-1111-111111111111",
            runtime: "iOS-17-0",
            state: "Shutdown"
        )
        let inspector = SimulatorInspector(coreSimulatorPath: fakeCoreSim)
        let results = await inspector.listDevices()
        XCTAssertEqual(results.count, 2)
        let booted = results.first { $0.isBooted }
        XCTAssertNotNil(booted)
        XCTAssertEqual(booted?.name, "Booted iPhone")
    }

    func test_listDevices_resultsSortedBySizeDescending() async throws {
        _ = try makeDevice(
            named: "Small",
            udid: "SMALL-1111-1111-1111-111111111111",
            runtime: "iOS-17-0",
            state: "Shutdown",
            fileCount: 1
        )
        _ = try makeDevice(
            named: "Big",
            udid: "BIG-1111-1111-1111-111111111111",
            runtime: "iOS-17-0",
            state: "Shutdown",
            fileCount: 10
        )
        let inspector = SimulatorInspector(coreSimulatorPath: fakeCoreSim)
        let results = await inspector.listDevices()
        XCTAssertEqual(results.count, 2)
        // Big has 10 data files vs Small's 1, so Big's total
        // must be strictly larger.
        XCTAssertGreaterThan(results[0].size, results[1].size)
        XCTAssertEqual(results[0].name, "Big")
    }

    func test_listDevices_deviceWithoutPlist_isSkipped() async throws {
        // Make a directory without a device.plist inside
        let dir = fakeCoreSim
            .appendingPathComponent("Devices", isDirectory: true)
            .appendingPathComponent("no-plist-device", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: dir.appendingPathComponent("data"))

        let inspector = SimulatorInspector(coreSimulatorPath: fakeCoreSim)
        let results = await inspector.listDevices()
        XCTAssertTrue(results.isEmpty)
    }
}
