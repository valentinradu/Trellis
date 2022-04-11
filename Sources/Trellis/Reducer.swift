//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

private final class Store<State> {
    private(set) var state: State

    init(initialState: State) {
        state = initialState
    }

    @MainActor func update<T>(_ closure: (inout State) -> T) -> T {
        closure(&state)
    }
}

public struct EmptyReducerContext {}

public struct EmptyReducerState {}

public struct Reducer<S, C, A>: Service where A: Action {
    public typealias SideEffect<C> = (Dispatch, C) async throws -> Void
    public typealias Reduce = (inout S, A) -> SideEffect<C>?
    private let _store: Store<S>
    private let _context: C
    private let _reduce: Reduce
    @Environment(\.dispatch) private var _dispatch
    @Environment(\.stateWatchers) private var _stateWatchers

    public init(reduce: @escaping Reduce)
        where S == EmptyReducerState, C == EmptyReducerContext
    {
        let state = EmptyReducerState()
        let context = EmptyReducerContext()
        self.init(state: state,
                  context: context,
                  reduce: reduce)
    }

    public init(initialState state: S, reduce: @escaping Reduce)
        where C == EmptyReducerContext
    {
        let context = EmptyReducerContext()
        self.init(state: state,
                  context: context,
                  reduce: reduce)
    }

    public init(context: C, reduce: @escaping Reduce)
        where S == EmptyReducerState
    {
        let state = EmptyReducerState()
        self.init(state: state,
                  context: context,
                  reduce: reduce)
    }

    public init(state: S,
                context: C,
                reduce: @escaping Reduce)
    {
        _store = Store(initialState: state)
        _reduce = reduce
        _context = context
    }

    public var body: some Service {
        EmptyService()
    }

    public func receive(action: any Action) async throws {
        guard let action = action as? A else {
            return
        }

        if let sideEffect = try await storeUpdate(action: action) {
            try await sideEffect(_dispatch, _context)
        }
    }

    private func storeUpdate(action: A) async throws -> SideEffect<C>? {
        let sideEffect = await _store.update {
            _reduce(&$0, action)
        }

        let watcher = _stateWatchers[ObjectIdentifier(S.self)]?.base as? StateWatcher<S>
        if let watcher = watcher {
            await watcher(_store.state)
        }

        return sideEffect
    }

    private func storeUpdate(action: A) async throws -> SideEffect<C>?
        where S: Equatable
    {
        let preState = _store.state

        let sideEffect = await _store.update {
            _reduce(&$0, action)
        }

        let watcher = _stateWatchers[ObjectIdentifier(S.self)]?.base as? StateWatcher<S>
        if let watcher = watcher, preState != _store.state {
            await watcher(_store.state)
        }

        return sideEffect
    }
}

public typealias StateWatcher<S> = (S) async -> Void

private struct AnyStateWatcher {
    let base: Any
    init<S>(_ watcher: @escaping StateWatcher<S>) {
        base = watcher
    }
}

private struct StateWatchersKey: EnvironmentKey {
    static var defaultValue: [ObjectIdentifier: AnyStateWatcher] = [:]
}

private extension EnvironmentValues {
    private(set) var stateWatchers: [ObjectIdentifier: AnyStateWatcher] {
        get { self[StateWatchersKey.self] }
        set { self[StateWatchersKey.self] = newValue }
    }
}

public extension Service {
    func watch<S>(_ type: S.Type, callback: @escaping StateWatcher<S>) -> some Service {
        transformEnvironment(\.stateWatchers) {
            var result = $0
            result[ObjectIdentifier(type)] = AnyStateWatcher(callback)
            return result
        }
    }
}
