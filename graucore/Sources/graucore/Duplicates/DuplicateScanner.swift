//
//  DuplicateScanner.swift
//  graucore
//
//  Three-phase duplicate detection:
//    1. Group by size — files with unique sizes cannot be dupes
//    2. Within each size group, hash the first 4 KB (partial)
//    3. Within each partial-hash group, full SHA-256
//
//  Honors Task.isCancelled. Returns groups of 2+ identical files.
//

import Foundation

public actor DuplicateScanner {

    private let hasher: FileHasher

    public init(hasher: FileHasher = FileHasher()) {
        self.hasher = hasher
    }

    public enum Phase: String, Sendable {
        case sizing
        case partialHashing
        case fullHashing
        case done
    }

    public enum ScannerEvent: Sendable {
        case phaseStarted(Phase)
        case phaseProgress(Phase, scanned: Int, total: Int)
        case phaseCompleted(Phase)
        case duplicateFound(DuplicateGroup)
    }

    public func scan(
        root: URL,
        exclusions: PathExclusionsProvider = PathExclusions.standard
    ) -> AsyncStream<ScannerEvent> {
        AsyncStream { continuation in
            let task = Task {
                await Self.runScan(
                    root: root,
                    exclusions: exclusions,
                    hasher: hasher,
                    continuation: continuation
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func runScan(
        root: URL,
        exclusions: PathExclusionsProvider,
        hasher: FileHasher,
        continuation: AsyncStream<ScannerEvent>.Continuation
    ) async {
        // Phase 1: collect all files + their sizes.
        continuation.yield(.phaseStarted(.sizing))
        let scanner = FileSystemScanner(exclusions: exclusions)
        let allFiles: [URL]
        do {
            allFiles = try await scanner.collectFiles(root: root)
        } catch {
            return
        }
        if Task.isCancelled { return }
        continuation.yield(.phaseCompleted(.sizing))

        // Group by size.
        var bySize: [Int64: [URL]] = [:]
        for url in allFiles {
            if Task.isCancelled { return }
            let size = (try? FileManager.default
                .attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            bySize[size, default: []].append(url)
        }
        let sizeCandidates = bySize.filter { $0.value.count > 1 }.flatMap { $0.value }
        if sizeCandidates.isEmpty { return }

        // Phase 2: partial hash.
        continuation.yield(.phaseStarted(.partialHashing))
        var partialBuckets: [String: [URL]] = [:]
        var processed = 0
        for url in sizeCandidates {
            if Task.isCancelled { return }
            do {
                let h = try hasher.partialHash(of: url)
                partialBuckets[h, default: []].append(url)
            } catch {
                continue
            }
            processed += 1
            if processed % 50 == 0 {
                continuation.yield(.phaseProgress(.partialHashing, scanned: processed, total: sizeCandidates.count))
            }
        }
        continuation.yield(.phaseCompleted(.partialHashing))
        let partialCandidates = partialBuckets
            .filter { $0.value.count > 1 }
            .flatMap { $0.value }
        if partialCandidates.isEmpty { return }

        // Phase 3: full hash.
        continuation.yield(.phaseStarted(.fullHashing))
        var fullBuckets: [String: [URL]] = [:]
        processed = 0
        for url in partialCandidates {
            if Task.isCancelled { return }
            do {
                let h = try hasher.fullHash(of: url)
                fullBuckets[h, default: []].append(url)
            } catch {
                continue
            }
            processed += 1
            if processed % 20 == 0 {
                continuation.yield(.phaseProgress(.fullHashing, scanned: processed, total: partialCandidates.count))
            }
        }
        continuation.yield(.phaseCompleted(.fullHashing))

        // Emit groups of 2+
        for (hash, files) in fullBuckets where files.count > 1 {
            if let size = (try? FileManager.default
                .attributesOfItem(atPath: files[0].path)[.size] as? Int64) {
                continuation.yield(.duplicateFound(
                    DuplicateGroup(hash: hash, size: ByteSize(bytes: size), files: files)
                ))
            }
        }
        continuation.yield(.phaseStarted(.done))
    }
}
