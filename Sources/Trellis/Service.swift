//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Foundation

/// The service name is used to identify the
/// service in various palces like the dispatcher.
public protocol ServiceName: Hashable {}

/// The pre middleware is called before all reducers.
/// If it throws, no reducers will perform mutations.
public typealias PreMid<S> = (S, AnyAction) throws -> Void

/// The post middleware is called after all reducers
/// but before any of the side effects.
public typealias PostMid<S> = (S, AnyAction) -> Void
/**
 When an action's side effect fails, this method is called to transform
 the resulting error into another action that gets dispatched forward.
 */
public typealias ErrorMid<S> = (Error, Dispatch, S, AnyAction) -> Void

class Store<State> {
    private(set) var state: State

    /// Initiates the store with a state.
    init(initialState: State) {
        state = initialState
    }

    @MainActor func update<T>(_ closure: (inout State) -> T) -> T {
        closure(&state)
    }
}

protocol Reactive {
    func pre(action: AnyAction) async throws -> Void
    func send(action: AnyAction) async -> ServiceResult
    func post(action: AnyAction) async -> Void
    func error(_ error: Error, dispatch: Dispatch, action: AnyAction) async -> Void
}

struct StatefulService<S>: Reactive {
    private let _store: Store<S>
    private let _reducers: [StatefulReducer<S>]
    private let _pre: ((AnyAction) throws -> Void)?
    private let _post: ((AnyAction) -> Void)?
    private let _error: ((Error, Dispatch, AnyAction) -> Void)?

    init(state: S,
         reducers: [StatefulReducer<S>],
         pre: PreMid<S>? = nil,
         post: PostMid<S>? = nil,
         error: ErrorMid<S>? = nil)
    {
        let store = Store(initialState: state)
        _reducers = reducers
        _store = store
        _pre = { action in
            try pre?(store.state, action)
        }
        _post = { action in
            post?(store.state, action)
        }
        _error = { err, dispatch, action in
            error?(err, dispatch, store.state, action)
        }
    }

    func pre(action: AnyAction) throws {
        try _pre?(action)
    }

    func send(action: AnyAction) async -> ServiceResult {
        var sideEffects: [ReducerResult] = []
        for reducer in _reducers {
            let sideEffect = await _store.update { state in
                reducer(state: &state,
                        action: action)
            }

            if !sideEffect.hasSideEffects {
                continue
            }

            sideEffects.append(sideEffect)
        }

        return ServiceResult(sideEffects: sideEffects)
    }

    func post(action: AnyAction) {
        _post?(action)
    }

    func error(_ error: Error, dispatch: Dispatch, action: AnyAction) {
        _error?(error, dispatch, action)
    }
}

/// Side effects are async reducer operations that don't mutate the state directly.
public typealias SideEffect<E> = (Dispatch, E) async throws -> Void

/// The result encapsulates the side effects of all the services in the pool for a specific action.
public struct ServiceResult {
    private let _sideEffects: () async -> [Result<Void, Error>]
    private let _hasSideEffects: Bool

    init(sideEffects: [ReducerResult]) {
        guard !sideEffects.isEmpty && sideEffects.allSatisfy({ $0.hasSideEffects }) else {
            _hasSideEffects = false
            _sideEffects = { [] }
            return
        }

        _sideEffects = {
            await withThrowingTaskGroup(of: Void.self, returning: [Result<Void, Error>].self) { taskGroup in
                for sideEffect in sideEffects {
                    taskGroup.addTask {
                        try await sideEffect()
                    }
                }

                var values = [Result<Void, Error>]()
                while let result = await taskGroup.nextResult() {
                    values.append(result)
                }

                return values
            }
        }

        _hasSideEffects = true
    }

    /// Checks if the result has any side effects.
    public var hasSideEffects: Bool {
        _hasSideEffects
    }

    /// Performs all enclosed side effects.
    public func callAsFunction() async -> [Result<Void, Error>] {
        guard _hasSideEffects else { return [] }
        return await _sideEffects()
    }
}
