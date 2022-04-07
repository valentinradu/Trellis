//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

class Store<State> {
    private(set) var state: State

    init(initialState: State) {
        state = initialState
    }

    @MainActor func update<T>(_ closure: (inout State) -> T) -> T {
        closure(&state)
    }
}

public struct EmptyContext {}

public struct EmptyState {}

public struct Reducer<S, C, A>: Service where A: Action {
    public typealias SideEffect<C> = (Dispatch, C) async throws -> Void
    public typealias Reduce = (inout S, A) -> SideEffect<C>?
    public typealias Pre = (S, A) async throws -> Void
    public typealias Post = (S, A) async -> Void
    private let _store: Store<S>
    private let _context: C
    private let _reduce: Reduce
    private let _pre: Pre?
    private let _post: Post?
    @Environment(\.dispatch) private var _dispatch

    public init(reduce: @escaping Reduce)
        where S == EmptyState, C == EmptyContext
    {
        let state = EmptyState()
        let context = EmptyContext()
        self.init(state: state,
                  context: context,
                  reduce: reduce,
                  pre: nil,
                  post: nil)
    }

    public init(initialState state: S, reduce: @escaping Reduce)
        where C == EmptyContext
    {
        let context = EmptyContext()
        self.init(state: state,
                  context: context,
                  reduce: reduce,
                  pre: nil,
                  post: nil)
    }

    public init(context: C, reduce: @escaping Reduce)
        where S == EmptyState
    {
        let state = EmptyState()
        self.init(state: state,
                  context: context,
                  reduce: reduce,
                  pre: nil,
                  post: nil)
    }

    public init(state: S, context: C, reduce: @escaping Reduce) {
        self.init(state: state,
                  context: context,
                  reduce: reduce,
                  pre: nil,
                  post: nil)
    }

    private init(state: S,
                 context: C,
                 reduce: @escaping Reduce,
                 pre: Pre?,
                 post: Post?)
    {
        _store = Store(initialState: state)
        _reduce = reduce
        _context = context
        _post = post
        _pre = pre
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

    public func pre(_ handler: @escaping Pre) -> Self {
        Reducer(state: _store.state,
                context: _context,
                reduce: _reduce,
                pre: handler,
                post: _post)
    }

    public func post(_ handler: @escaping Post) -> Self {
        Reducer(state: _store.state,
                context: _context,
                reduce: _reduce,
                pre: _pre,
                post: handler)
    }

    private func storeUpdate(action: A) async throws -> SideEffect<C>? {
        if let pre = _pre {
            try await pre(_store.state, action)
        }

        let sideEffect = await _store.update {
            _reduce(&$0, action)
        }

        if let post = _post {
            await post(_store.state, action)
        }

        return sideEffect
    }

    private func storeUpdate(action: A) async throws -> SideEffect<C>?
        where S: Equatable
    {
        if let pre = _pre {
            try await pre(_store.state, action)
        }

        let preState = _store.state

        let sideEffect = await _store.update {
            _reduce(&$0, action)
        }

        if let post = _post, preState != _store.state {
            await post(_store.state, action)
        }

        return sideEffect
    }
}

extension Reducer: NodeBuilder {}
