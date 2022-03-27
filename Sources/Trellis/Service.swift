//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Foundation

class Store<State> where State: ObservableObject {
    private var state: State

    /// Initiates the store with a state.
    init(initialState: State) {
        state = initialState
    }

    @MainActor func update<T>(_ closure: (inout State) -> T) -> T {
        closure(&state)
    }
}

protocol Service {
    func send<A>(action: A) async -> ServiceResult where A: Action
}

struct StatefulService<S>: Service where S: ObservableObject {
    private let _store: Store<S>
    private let _reducers: [StatefulReducer<S>]

    init(state: S,
         reducers: [StatefulReducer<S>])
    {
        _reducers = reducers
        _store = Store(initialState: state)
    }

    func send<A>(action: A) async -> ServiceResult
        where A: Action
    {
        var sideEffects: [ReducerResult] = []
        for reducer in _reducers {
            let sideEffect = await _store.update { state in
                reducer.reduce(state: &state,
                               action: action)
            }

            if !sideEffect.hasSideEffects {
                continue
            }

            sideEffects.append(sideEffect)
        }

        return ServiceResult(sideEffects: sideEffects)
    }
}

/// Side effects are async reducer operations that don't mutate the state directly.
public typealias SideEffect<E> = (Dispatch, E) async throws -> Void where E: Actor

/// The result encapsulates the side effects of all the services in the pool for a specific action.
public struct ServiceResult {
    private let _sideEffects: () async -> Void
    private let _hasSideEffects: Bool

    init(sideEffects: [ReducerResult]) {
        guard !sideEffects.isEmpty && sideEffects.allSatisfy({ $0.hasSideEffects }) else {
            _hasSideEffects = false
            _sideEffects = {}
            return
        }

        _sideEffects = {
            await withTaskGroup(of: Void.self) { taskGroup in
                for sideEffect in sideEffects {
                    taskGroup.addTask {
                        await sideEffect()
                    }
                }
            }
        }

        _hasSideEffects = true
    }

    /// Checks if the result has any side effects.
    public var hasSideEffects: Bool {
        _hasSideEffects
    }

    /// Performs all enclosed side effects.
    public func callAsFunction() async {
        guard _hasSideEffects else { return }
        await _sideEffects()
    }
}
