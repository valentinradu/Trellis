//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public typealias Dispatch = (AnyAction) -> Void

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
    private var _tasks: [AnyHashable: Task<Void, Never>]
    private var _items: AnyActionable!
    public init(@ActionableBuilder _ itemsBuilder: @escaping () -> I) {
        _tasks = [:]
        _items = AnyActionable(
            itemsBuilder()
                .environment(\.dispatch, value: send)
        )
    }

    public func receive(action: AnyAction) async throws {
        try await _items.receive(action: action)
    }

    public func send(action: AnyAction) {
        if let olderTask = _tasks[action] {
            olderTask.cancel()
        }

        let task = Task { [weak self] in
            do {
                try await self?.receive(action: action)
            } catch {
                switch _failureStrategy {
                case .fail:
                    assertionFailure("\(action) failed without a catch handler")
                case let .catch(handler):
                    self?.send(action: handler(error))
                }
            }
            self?._tasks.removeValue(forKey: action)
        }
        _tasks[action] = task
    }
}
