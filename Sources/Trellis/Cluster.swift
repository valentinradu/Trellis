//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public typealias Dispatch = (AnyAction) async throws -> Void

private struct DispatchKey: EnvironmentKey {
    public static var defaultValue: Dispatch = { _ in }
}

public extension EnvironmentValues {
    private(set) var dispatch: Dispatch {
        get { self[DispatchKey.self] }
        set { self[DispatchKey.self] = newValue }
    }
}

public class Cluster<I>: Actionable
    where I: Actionable
{
    @Environment(\.failureStrategy) private var _failureStrategy
    private var _tasks: [AnyHashable: Task<Void, Error>]
    private var _items: I
    public init(@ActionableBuilder _ itemsBuilder: () -> I) {
        _tasks = [:]
        _items = itemsBuilder()
    }

    public func receive<A>(action: A) async throws where A: Action {
        if let olderTask = _tasks[action] {
            olderTask.cancel()
        }

        let task = Task {
            do {
                try Task.checkCancellation()
                try await _items.receive(action: action)
            } catch {
                switch _failureStrategy {
                case .fail:
                    throw error
                case let .catch(handler):
                    let action = handler(error)
                    try await _items.receive(action: action)
                }
            }
        }

        _tasks[action] = task
        defer {
            _tasks.removeValue(forKey: action)
        }

        try await task.value
    }
}
