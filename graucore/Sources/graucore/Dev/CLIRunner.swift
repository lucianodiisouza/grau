//
//  CLIRunner.swift
//  graucore
//
//  Process wrapper for shelling out to CLIs (docker, mas, brew).
//  Used by the Docker inspector. Honors a timeout.
//

import Foundation

public struct CLIRunner: Sendable {

    public let timeout: TimeInterval

    public init(timeout: TimeInterval = 5) {
        self.timeout = timeout
    }

    public struct CLIResult: Sendable {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32
    }

    public enum CLIError: Error, CustomStringConvertible {
        case notFound(String)
        case timeout(String)
        case nonZeroExit(exitCode: Int32, stderr: String)
        public var description: String {
            switch self {
            case .notFound(let exe):
                return "Executable not found: \(exe)"
            case .timeout(let exe):
                return "Command timed out: \(exe)"
            case .nonZeroExit(let code, let stderr):
                return "Command exited with code \(code): \(stderr)"
            }
        }
    }

    /// Resolves an executable name to an absolute path via
    /// `which`. Returns nil if not found.
    public static func which(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs `executable` with `arguments`. Throws on timeout,
    /// non-zero exit, or missing executable.
    public func run(
        _ executable: String,
        arguments: [String] = []
    ) async throws -> CLIResult {
        let resolved: String
        if executable.hasPrefix("/") {
            resolved = executable
        } else if let path = Self.which(executable) {
            resolved = path
        } else {
            throw CLIError.notFound(executable)
        }

        return try await withThrowingTaskGroup(of: CLIResult.self) { group in
            group.addTask {
                try await Self.runProcess(
                    executable: resolved, arguments: arguments
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeout))
                throw CLIError.timeout(executable)
            }
            // Whichever finishes first
            for try await result in group {
                group.cancelAll()
                return result
            }
            throw CLIError.timeout(executable)  // unreachable
        }
    }

    private static func runProcess(
        executable: String,
        arguments: [String]
    ) async throws -> CLIResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.terminationHandler = { p in
                let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                continuation.resume(returning: CLIResult(
                    stdout: stdout, stderr: stderr, exitCode: p.terminationStatus
                ))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
