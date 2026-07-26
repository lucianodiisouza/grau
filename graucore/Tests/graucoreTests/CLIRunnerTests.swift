//
//  CLIRunnerTests.swift
//  graucoreTests
//

import XCTest
@testable import graucore

final class CLIRunnerTests: XCTestCase {

    func test_which_findsBinInPath() {
        // /bin/ls is part of macOS and is always in PATH
        let path = CLIRunner.which("ls")
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.hasPrefix("/") ?? false)
    }

    func test_which_returnsNilForUnknownExecutable() {
        XCTAssertNil(CLIRunner.which("grau-does-not-exist-\(UUID().uuidString)"))
    }

    func test_run_executesSimpleCommand() async throws {
        let runner = CLIRunner(timeout: 5)
        let result = try await runner.run("/bin/echo", arguments: ["hello", "world"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("hello world"))
    }

    func test_run_throwsNotFoundForMissingExecutable() async {
        let runner = CLIRunner(timeout: 1)
        do {
            _ = try await runner.run("grau-missing-\(UUID().uuidString)")
            XCTFail("Should have thrown .notFound")
        } catch CLIRunner.CLIError.notFound {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_run_usesAbsolutePathDirectly() async throws {
        // No `which` lookup when path starts with `/`
        let runner = CLIRunner(timeout: 5)
        // /usr/bin/true is the macOS canonical location
        let result = try await runner.run("/usr/bin/true")
        XCTAssertEqual(result.exitCode, 0)
    }

    func test_cliResult_initialization() {
        let r = CLIRunner.CLIResult(stdout: "out", stderr: "err", exitCode: 0)
        XCTAssertEqual(r.stdout, "out")
        XCTAssertEqual(r.stderr, "err")
        XCTAssertEqual(r.exitCode, 0)
    }

    func test_cliError_descriptions() {
        XCTAssertEqual(
            CLIRunner.CLIError.notFound("foo").description,
            "Executable not found: foo"
        )
        XCTAssertEqual(
            CLIRunner.CLIError.timeout("bar").description,
            "Command timed out: bar"
        )
        XCTAssertEqual(
            CLIRunner.CLIError.nonZeroExit(exitCode: 7, stderr: "boom").description,
            "Command exited with code 7: boom"
        )
    }
}
