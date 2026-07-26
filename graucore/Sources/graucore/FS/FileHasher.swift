//
//  FileHasher.swift
//  graucore
//
//  Streaming SHA-256 (CryptoKit) and a partial-hash of the first
//  4 KB. Used by the duplicates finder (Phase 4) to avoid
//  hashing every file fully.
//

import CryptoKit
import Foundation

public struct FileHasher: Sendable {

    public init() {}

    /// Number of bytes hashed in the partial-hash. Tuned in
    /// docs/DATA-SOURCES.md § 4.
    public static let partialSize = 4 * 1024

    public enum HashError: Error, CustomStringConvertible {
        case readFailed(URL, underlying: Error)
        public var description: String {
            switch self {
            case .readFailed(let url, let err):
                return "Failed to read \(url.path): \(err.localizedDescription)"
            }
        }
    }

    /// Reads the first 4 KB of `url` and returns its SHA-256 hex
    /// digest. Cheap; used to bucket files that might be dupes.
    public func partialHash(of url: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw HashError.readFailed(url, underlying: error)
        }
        defer { try? handle.close() }
        let data: Data
        do {
            data = try handle.read(upToCount: Self.partialSize) ?? Data()
        } catch {
            throw HashError.readFailed(url, underlying: error)
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Streams the entire file and returns its SHA-256 hex digest.
    /// For very large files this can be slow; use `partialHash` for
    /// bucketing and only call this for files that survived the
    /// partial-hash filter.
    public func fullHash(of url: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw HashError.readFailed(url, underlying: error)
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk: Data
            do {
                guard let data = try handle.read(upToCount: 1024 * 1024) else { break }
                chunk = data
            } catch {
                throw HashError.readFailed(url, underlying: error)
            }
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
