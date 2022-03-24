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
    private let _reducers: [ReducerContext<S>]

    init(store: Store<S>,
         reducers: [ReducerContext<S>])
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

            if case .none = sideEffect {
                continue
            }

            sideEffects.append(sideEffect)
        }

        if sideEffects.isEmpty {
            return ServiceResult.none
        }
        else {
            return ServiceResult(sideEffects: sideEffects)
        }
    }
}

public enum ServiceResult {
    case none
    case sideEffects(() async -> Void)
    init(sideEffects: [ReducerResult]) {
        self = .sideEffects {
            await withTaskGroup(of: Void.self) { taskGroup in
                for sideEffect in sideEffects {
                    taskGroup.addTask {
                        await sideEffect.performSideEffects()
                    }
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
