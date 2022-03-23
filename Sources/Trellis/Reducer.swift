//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

struct Reducer<A, S> where A: Action {
    private let _operation: (inout S, A) -> ActionSideEffect
    init<E>(dispatcher: Dispatcher,
            environment: E,
            operation: @escaping (inout S, A) -> SideEffect<E>) where E: Actor
    {
        _operation = { state, action in
            let sideEffect = operation(&state, action)
            return ActionSideEffect(dispatcher: dispatcher,
                                     environment: environment,
                                     action: action,
                                     sideEffect: sideEffect)
        }
    }

    func callAsFunction(state: inout S, action: A) -> ActionSideEffect {
        _operation(&state, action)
    }
}

struct AnyReducer {
    let base: Any
    init<A, S>(_ reducer: Reducer<A, S>)
        where A: Action
    {
        base = reducer
    }
}
