//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

/// The state mutating operation: `(&state, action) -> SideEffect`.
public typealias Reducer<E, S, A> = (inout S, A) -> SideEffect<E>? where A: Action

public struct StatefulReducer<S> {
    private let _operation: (inout S, AnyAction) -> ReducerResult

    init<E, A>(dispatch: Dispatch,
               environment: E,
               reducer: @escaping Reducer<E, S, A>)
    {
        _operation = { state, action in
            if let action = action as? A ?? action.base as? A {
                if let sideEffect = reducer(&state, action) {
                    return ReducerResult(dispatch: dispatch,
                                         environment: environment,
                                         sideEffect: sideEffect)
                }
                else {
                    return .none
                }
            }
            else {
                return .none
            }
        }
    }

    func callAsFunction(state: inout S, action: AnyAction) -> ReducerResult {
        _operation(&state, action)
    }
}

struct ReducerResult {
    public static var none: ReducerResult { .init() }
    private let _operation: () async throws -> Void
    private let _hasSideEffects: Bool

    init<E>(dispatch: Dispatch,
            environment: E,
            sideEffect: @escaping SideEffect<E>)
    {
        _operation = {
            try Task.checkCancellation()
            try await sideEffect(dispatch, environment)
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

    func callAsFunction() async throws {
        guard _hasSideEffects else { return }
        try await _operation()
    }
}
