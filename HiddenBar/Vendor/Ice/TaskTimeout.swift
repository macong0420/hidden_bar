//
//  TaskTimeout.swift
//  HiddenBar
//
//  Adapted from Ice (https://github.com/jordanbaird/Ice)
//  Copyright (c) Jordan Baird — Licensed under GNU GPL v3.0 or later.
//

import Foundation

extension Task where Failure == any Error {
    @discardableResult
    init<C: Clock>(
        priority: TaskPriority? = nil,
        timeout: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
        operation: @escaping @Sendable () async throws -> Success
    ) {
        self.init(priority: priority) {
            try await Task.run(operation: operation, withTimeout: timeout, tolerance: tolerance, clock: clock)
        }
    }

    private static func run<C: Clock>(
        operation: @escaping @Sendable () async throws -> Success,
        withTimeout timeout: C.Instant.Duration,
        tolerance: C.Instant.Duration?,
        clock: C
    ) async throws -> Success {
        try await withThrowingTaskGroup(of: Success.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await _Concurrency.Task.sleep(for: timeout, tolerance: tolerance, clock: clock)
                throw TaskTimeoutError()
            }
            guard let success = try await group.next() else {
                throw _Concurrency.CancellationError()
            }
            group.cancelAll()
            return success
        }
    }
}

struct TaskTimeoutError: Error, CustomStringConvertible, LocalizedError {
    let description = "Task timed out before completion"
    var errorDescription: String? { description }
}
