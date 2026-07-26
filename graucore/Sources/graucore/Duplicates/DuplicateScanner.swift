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
    /// Maximum number of in-flight hash tasks. 8 is a sane default
    /// for a desktop app — keeps disk IO reasonable while
    /// parallelizing well enough to scan a 50k-file home in a
    /// couple of minutes.
    public let maxParallelism: Int

    public init(hasher: FileHasher = FileHasher(), maxParallelism: Int = 8) {
        self.hasher = hasher
        self.maxParallelism = max(1, maxParallelism)
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
                    parallelism: maxParallelism,
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
        parallelism: Int,
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

        // Phase 2: partial hash (parallel).
        continuation.yield(.phaseStarted(.partialHashing))
        let partialBuckets = await hashInParallel(
            urls: sizeCandidates,
            hash: { try hasher.partialHash(of: $0) },
            parallelism: parallelism,
            progress: { processed, total in
                continuation.yield(.phaseProgress(.partialHashing, scanned: processed, total: total))
            }
        )
        if Task.isCancelled { return }
        continuation.yield(.phaseCompleted(.partialHashing))
        let partialCandidates = partialBuckets
            .filter { $0.value.count > 1 }
            .flatMap { $0.value }
        if partialCandidates.isEmpty { return }

        // Phase 3: full hash (parallel).
        continuation.yield(.phaseStarted(.fullHashing))
        let fullBuckets = await hashInParallel(
            urls: partialCandidates,
            hash: { try hasher.fullHash(of: $0) },
            parallelism: parallelism,
            progress: { processed, total in
                continuation.yield(.phaseProgress(.fullHashing, scanned: processed, total: total))
            }
        )
        if Task.isCancelled { return }
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

    /// Hashes every URL in parallel using up to `parallelism`
    /// in-flight tasks. Errors are swallowed (we can't report them
    /// per-file; failed files just don't appear in the result).
    /// Returns a dict of `hash → [url]` preserving duplicates
    /// (multiple files hashing to the same value accumulate in
    /// the same array).
    private static func hashInParallel(
        urls: [URL],
        hash: @escaping (URL) throws -> String,
        parallelism: Int,
        progress: (Int, Int) -> Void
    ) async -> [String: [URL]] {
        let total = urls.count
        var buckets: [String: [URL]] = [:]
        var processed = 0
        let lock = NSLock()

        await withTaskGroup(of: (String, URL)?.self) { group in
            // Index-based submission so we can pull the next URL
            // out of a counter as workers become free.
            var nextIndex = 0
            let submitLock = NSLock()

            // Seed the group with `parallelism` tasks.
            for _ in 0..<min(parallelism, urls.count) {
                let idx = nextIndex
                nextIndex += 1
                let url = urls[idx]
                group.addTask {
                    do {
                        let h = try hash(url)
                        return (h, url)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if Task.isCancelled {
                    group.cancelAll()
                    return
                }
                if let (h, url) = result {
                    lock.lock()
                    buckets[h, default: []].append(url)
                    lock.unlock()
                }
                processed += 1
                if processed % 50 == 0 {
                    progress(processed, total)
                }
                // Pull the next URL if any remain.
                submitLock.lock()
                if nextIndex < urls.count {
                    let idx = nextIndex
                    nextIndex += 1
                    let url = urls[idx]
                    submitLock.unlock()
                    group.addTask {
                        do {
                            let h = try hash(url)
                            return (h, url)
                        } catch {
                            return nil
                        }
                    }
                } else {
                    submitLock.unlock()
                }
            }
        }
        progress(total, total)
        return buckets
    }
}
