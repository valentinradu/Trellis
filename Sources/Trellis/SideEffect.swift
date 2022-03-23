//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

public enum SideEffect<E> where E: Actor {
    public typealias Operation = (Dispatcher, E) async throws -> Void
    case noop
    case operation(Operation)

    public init(_ operation: @escaping Operation) {
        self = .operation(operation)
    }

    func callAsFunction(dispatcher: Dispatcher, environment: E) async throws {
        switch self {
        case .noop:
            break
        case let .operation(operation):
            try await operation(dispatcher, environment)
        }
    }
}
