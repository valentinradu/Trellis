//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Foundation

public actor Service<E, S> where E: Actor {
    private var _environment: E
    private var _dispatcher: Dispatcher
    private var _store: Store<S>
    private var _reducers: [Reducer<S>]

    public init(dispatcher: Dispatcher,
                environment: E,
                store: Store<S>)
    {
        _dispatcher = dispatcher
        _environment = environment
        _store = store
        _reducers = []
    }

    public func add<A>(reducer operation: @escaping (inout S, A) -> SideEffect<E>) where A: Action {
        let reducer = Reducer(dispatcher: _dispatcher,
                              environment: _environment,
                              operation: operation)
        _reducers.append(reducer)
    }

    public func replace(dispatcher: Dispatcher) async {
        _dispatcher = dispatcher
    }

    public func replace(environment: E) {
        _environment = environment
    }

    public func replace(store: Store<S>) {
        _store = store
    }

    public func reduce<A>(action: A) async -> ActionSideEffectGroup
        where A: Action
    {
        var sideEffects: [ActionSideEffect] = []
        for reducer in _reducers {
            let sideEffect = await _store.update { (state: inout S) -> ActionSideEffect in
                reducer(state: &state, action: action)
            }

            if case .noop = sideEffect {
                continue
            }

            sideEffects.append(sideEffect)
        }

        if sideEffects.isEmpty {
            return .noop
        }
        else {
            return ActionSideEffectGroup(sideEffects: sideEffects)
        }
    }
}
