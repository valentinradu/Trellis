//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

public struct Reducer<E, S, A> where E: Actor, A: Action {
    public typealias Operation = (inout S, A) -> SideEffect<E>
    private let _operation: Operation
    public init(_ operation: @escaping Operation) {
        _operation = operation
    }

    public func callAsFunction(state: inout S, action: A) -> SideEffect<E> {
        _operation(&state, action)
    }
}

enum ReducerResult {
    case none
    case sideEffects(() async -> Void)

    init<E, A>(dispatcher: Dispatcher,
               environment: E,
               action: A,
               sideEffect: SideEffect<E>)
        where E: Actor, A: Action
    {
        self = .sideEffects {
            do {
                try await sideEffect(dispatcher: dispatcher,
                                     environment: environment)
            }
            catch {
                let actionTransform = action.transform(error: error)

                switch actionTransform {
                case .none:
                    break
                case let .to(newAction):
                    await dispatcher.send(action: newAction)
                }
            }
        }
    }

    func performSideEffects() async {
        switch self {
        case .none:
            break
        case let .sideEffects(operation):
            await operation()
        }
    }
}

struct ReducerContext<S> {
    private let _operation: (inout S, Any) -> ReducerResult

    init<E, A>(dispatcher: Dispatcher,
               environment: E,
               reducer: Reducer<E, S, A>)
        where E: Actor, A: Action
    {
        _operation = { state, action in
            if let action = action as? A {
                let sideEffect = reducer(state: &state, action: action)
                return ReducerResult(dispatcher: dispatcher,
                                     environment: environment,
                                     action: action,
                                     sideEffect: sideEffect)
            }
            else {
                return .none
            }
        }
    }

    func reduce<A>(state: inout S, action: A) -> ReducerResult
        where A: Action
    {
        _operation(&state, action)
    }
}
