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

struct ActionSideEffect {
    private let _operation: () async -> Void
    init<E, A>(dispatcher: Dispatcher,
               environment: E,
               action: A,
               sideEffect: SideEffect<E>) where E: Actor, A: Action
    {
        _operation = {
            do {
                try await sideEffect(dispatcher: dispatcher,
                                     environment: environment)
            }
            catch {
                let actionTransform = action.transform(error: error)

                switch actionTransform {
                case .none:
                    break
                case let .to(action):
                    await dispatcher.send(action: action)
                }
            }
        }
    }

    func callAsFunction() async {
        await _operation()
    }
}

public actor ActionSideEffectGroup {
    private let _operation: () async -> Void
    init(sideEffects: [ActionSideEffect]) {
        _operation = {
            await withTaskGroup(of: Void.self) { taskGroup in
                for sideEffect in sideEffects {
                    taskGroup.addTask {
                        await sideEffect()
                    }
                }
            }
        }
    }

    public func callAsFunction() async {
        await _operation()
    }
}
