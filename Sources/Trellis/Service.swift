//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Foundation

protocol Service {
    func send<A>(action: A) async -> ServiceResult
        where A: Action
}

struct StatefulService<S>: Service {
    private let _store: Store<S>
    private let _reducers: [StatefulReducer<S>]

    init(store: Store<S>,
         reducers: [StatefulReducer<S>])
    {
        _reducers = reducers
        _store = store
    }

    func send<A>(action: A) async -> ServiceResult
        where A: Action
    {
        var sideEffects: [ReducerResult] = []
        for reducer in _reducers {
            let sideEffect = await _store.update { (state: inout S) -> ReducerResult in
                reducer.reduce(state: &state, action: action)
            }

            if !sideEffect.hasSideEffects {
                continue
            }

            sideEffects.append(sideEffect)
        }

        return ServiceResult(sideEffects: sideEffects)
    }
}

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
                        await sideEffect.performSideEffects()
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
    public func performSideEffects() async {
        guard _hasSideEffects else { return }
        await _sideEffects()
    }
}
