//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

/// Side effects are async reducer operations that don't mutate the state directly.
public struct SideEffect<E> where E: Actor {
    public typealias Operation = (Dispatcher, E) async throws -> Void
    public static var none: SideEffect<E> { .init() }
    private let _hasOperation: Bool
    private let _operation: Operation

    public init(_ operation: @escaping Operation) {
        _operation = operation
        _hasOperation = true
    }

    private init() {
        _operation = { _, _ in }
        _hasOperation = false
    }

    var hasOperation: Bool {
        _hasOperation
    }

    func callAsFunction(dispatcher: Dispatcher, environment: E) async throws {
        guard _hasOperation else { return }
        try await _operation(dispatcher, environment)
    }
}
