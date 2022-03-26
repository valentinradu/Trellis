//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

/// A collection of reducers
public protocol ReducerCollection {}

/// The environment for services with no explicit environment.
public actor EmptyEnvironment {}

/// The state for services with no explicit state.
public struct EmptyState {}

/// The empty collection of reducers for services with no explicit reducers.
public struct EmptyReducers: ReducerCollection {}

/// The service's collection of reducers
public struct AnyReducers<S>: ReducerCollection
{
    private let _items: [StatefulReducer<S>]
    init(_ items: [StatefulReducer<S>] = [])
    {
        _items = items
    }

    var items: [StatefulReducer<S>]
    {
        _items
    }

    static func +(lhs: Self, rhs: StatefulReducer<S>) -> Self
    {
        AnyReducers(lhs._items + [rhs])
    }
}

/// The service builder for bootstrapping services. This is usually created by the service pool.
@MainActor
public struct ServiceBuilder<E, S, R>
    where E: Actor, R: ReducerCollection
{
    private let _id: AnyHashable
    private let _dispatch: Dispatch
    private let _store: Store<S>
    private let _environment: E
    private let _reducers: R

    fileprivate init<ID: Hashable>(id: ID,
                                   dispatch: Dispatch)
        where S == EmptyState, E == EmptyEnvironment, R == EmptyReducers
    {
        _id = id
        _dispatch = dispatch
        _reducers = EmptyReducers()
        _environment = EmptyEnvironment()
        _store = Store(initialState: EmptyState())
    }

    fileprivate init<ID: Hashable>(id: ID,
                                   dispatch: Dispatch,
                                   store: Store<S>,
                                   environment: E,
                                   reducers: R)
    {
        _id = id
        _dispatch = dispatch
        _reducers = reducers
        _environment = environment
        _store = store
    }

    /// Set the initial store for the service.
    public func set<IS>(initialState: IS) -> ServiceBuilder<E, IS, AnyReducers<IS>>
        where S == EmptyState, R == EmptyReducers
    {
        ServiceBuilder<E, IS, AnyReducers<IS>>(id: _id,
                                               dispatch: _dispatch,
                                               store: Store(initialState: initialState),
                                               environment: _environment,
                                               reducers: AnyReducers())
    }

    /// Sets the environment for the service.
    public func set<NE>(environment: NE) -> ServiceBuilder<NE, S, R>
        where E == EmptyEnvironment, NE: Actor
    {
        ServiceBuilder<NE, S, R>(id: _id,
                                 dispatch: _dispatch,
                                 store: _store,
                                 environment: environment,
                                 reducers: _reducers)
    }

    /// Adds a new reducer to the service.
    public func add<A>(reducer: Reducer<E, S, A>) -> ServiceBuilder<E, S, R>
        where A: Action, R == AnyReducers<S>
    {
        let reducer = StatefulReducer(dispatch: _dispatch,
                                      environment: _environment,
                                      reducer: reducer)
        return ServiceBuilder(id: _id,
                              dispatch: _dispatch,
                              store: _store,
                              environment: _environment,
                              reducers: _reducers + reducer)
    }

    /// Adds a new reducer to the service.
    public func add<A>(reducer: Reducer<E, S, A>) -> ServiceBuilder<E, S, AnyReducers<S>>
        where A: Action, R == EmptyReducers
    {
        let reducer = StatefulReducer(dispatch: _dispatch,
                                      environment: _environment,
                                      reducer: reducer)
        return ServiceBuilder<E, S, AnyReducers<S>>(id: _id,
                                                    dispatch: _dispatch,
                                                    store: _store,
                                                    environment: _environment,
                                                    reducers: AnyReducers([reducer]))
    }

    /// Bootstraps everything, creates and registers the service with the dispatch.
    public func bootstrap()
        where R == AnyReducers<S>
    {
        let service = StatefulService(store: _store,
                                      reducers: _reducers.items)
        _dispatch.register(_id, service: service)
    }
}

/// The service pool is a collection of services that share the same dispatch.
@MainActor
public struct ServicePool<ID> where ID: Hashable
{
    /// The dispatch shared between all the services in the pool.
    public let dispatch: Dispatch

    public init()
    {
        dispatch = .init()
    }

    /// Starts the process of creating a new service.
    public func build(service: ID) -> ServiceBuilder<EmptyEnvironment, EmptyState, EmptyReducers>
        where ID: Hashable
    {
        ServiceBuilder(id: service,
                       dispatch: dispatch)
    }

    /// Removes a service from the pool.
    public func remove(service: ID) async
    {
        dispatch.unregister(service)
    }
}
