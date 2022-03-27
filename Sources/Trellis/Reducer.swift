//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

/// The reducer wraps the state mutating operation: `(&state, action) -> SideEffect`.
public typealias Reducer<E, S, A> = (inout S, A) -> SideEffect<E>? where E: Actor, A: Action

struct ReducerResult {
    public static var none: ReducerResult { .init() }
    private let _operation: () async -> Void
    private let _hasSideEffects: Bool

    init<E, A>(dispatch: Dispatch,
               environment: E,
               action: A,
               sideEffect: @escaping SideEffect<E>)
        where E: Actor, A: Action
    {
        _operation = {
            do {
                try Task.checkCancellation()
                try await sideEffect(dispatch, environment)
            }
            catch {
                let actionTransform = action.transform(error: error)

                switch actionTransform {
                case .none:
                    break
                case let .to(newAction):
                    await dispatch(action: newAction)
                }
            }
        }

        _hasSideEffects = true
    }

    init() {
        _operation = {}
        _hasSideEffects = false
    }

    var hasSideEffects: Bool {
        _hasSideEffects
    }

    func callAsFunction() async {
        guard _hasSideEffects else { return }
        await _operation()
    }
}

struct StatefulReducer<S> {
    private let _operation: (inout S, Any) -> ReducerResult

    init<E, A>(dispatch: Dispatch,
               environment: E,
               reducer: @escaping Reducer<E, S, A>)
        where E: Actor, A: Action
    {
        _operation = { state, action in
            if let action = action as? A,
               let sideEffect = reducer(&state, action)
            {
                return ReducerResult(dispatch: dispatch,
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
