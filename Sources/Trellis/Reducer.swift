//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

struct Reducer<S> {
    private let _operation: (inout S, Any) -> ActionSideEffect

    init<E, A>(dispatcher: Dispatcher,
               environment: E,
               operation: @escaping (inout S, A) -> SideEffect<E>)
        where E: Actor, A: Action
    {
        _operation = { state, action in
            if let action = action as? A
            {
                let sideEffect = operation(&state, action)
                return ActionSideEffect(dispatcher: dispatcher,
                                        environment: environment,
                                        action: action,
                                        sideEffect: sideEffect)
            }
            else
            {
                return .noop
            }
        }
    }

    func callAsFunction<A>(state: inout S, action: A) -> ActionSideEffect
        where A: Action
    {
        _operation(&state, action)
    }
}
