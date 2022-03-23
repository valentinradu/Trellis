//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

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
                case let .to(action):
                    await dispatcher.send(action: action)
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

struct Reducer<S> {
    private let _operation: (inout S, Any) -> ReducerResult

    init<E, A>(dispatcher: Dispatcher,
               environment: E,
               operation: @escaping (inout S, A) -> SideEffect<E>)
        where E: Actor, A: Action
    {
        _operation = { state, action in
            if let action = action as? A {
                let sideEffect = operation(&state, action)
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
