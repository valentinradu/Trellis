//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Foundation

public actor Store<State> {
    public private(set) var state: State

    public init(_ state: State) {
        self.state = state
    }

    internal func update<T>(_ closure: (inout State) -> T) -> T {
        return closure(&state)
    }
}

public enum SideEffect<E> where E: Actor {
    public typealias Operation = (Dispatcher, E) async throws -> Void
    case noop
    case sideEffects(Operation)

    public init(_ operation: @escaping Operation) {
        self = .sideEffects(operation)
    }

    public func callAsFunction(dispatcher: Dispatcher, environment: E) async throws {
        switch self {
        case .noop:
            break
        case let .sideEffects(operation):
            try await operation(dispatcher, environment)
        }
    }
}

public enum ReducerResult<E> where E: Actor {
    case ignore
    case resolve(SideEffect<E>)
}

public struct Reducer<E, S> where E: Actor {
    internal typealias Operation = (inout S, AnyAction) -> ReducerResult<E>
    private let _operation: Operation
    public init<A>(_ operation: @escaping (inout S, A) -> SideEffect<E>) where A: Action {
        _operation = { state, action in
            if let action = action.base as? A {
                return .resolve(operation(&state, action))
            }
            return .ignore
        }
    }

    internal func reduce(state: inout S, action: AnyAction) -> ReducerResult<E> {
        _operation(&state, action)
    }
}

public actor Service<E, S>: StatefulReducer where E: Actor {
    private var _environment: E
    private var _store: Store<S>
    private var _reducers: [Reducer<E, S>]

    public init(environment: E, store: Store<S>) {
        _environment = environment
        _store = store
        _reducers = []
    }

    public func add<A>(reducer: @escaping (inout S, A) -> SideEffect<E>) where A: Action {
        _reducers.append(Reducer(reducer))
    }

    public func replace(environment: E) {
        _environment = environment
    }

    public func replace(store: Store<S>) {
        _store = store
    }

    internal func reduce(action: AnyAction) async -> StatefulReducerResult {
        var sideEffects: [SideEffect<E>] = []
        for reducer in _reducers {
            let result = await _store.update { (state: inout S) -> ReducerResult<E> in
                reducer.reduce(state: &state, action: action)
            }

            switch result {
            case .ignore:
                continue
            case let .resolve(sideEffect):
                sideEffects.append(sideEffect)
            }
        }

        if !sideEffects.isEmpty {
            return .resolve { [weak self] dispatcher in
                for sideEffect in sideEffects {
                    if let self = self {
                        try await sideEffect(dispatcher: dispatcher,
                                             environment: self._environment)
                    }
                }
            }
        } else {
            return .ignore
        }
    }
}
