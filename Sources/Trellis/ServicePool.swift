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
public struct ServiceBuilder<E, S, R>
    where E: Actor, R: ReducerCollection
{
    private let _id: AnyHashable
    private let _dispatcher: Dispatcher
    private let _store: Store<S>
    private let _environment: E
    private let _reducers: R

    fileprivate init<ID: Hashable>(id: ID,
                                   dispatcher: Dispatcher)
        where S == EmptyState, E == EmptyEnvironment, R == EmptyReducers
    {
        _id = id
        _dispatcher = dispatcher
        _reducers = EmptyReducers()
        _environment = EmptyEnvironment()
        _store = Store(initialState: EmptyState())
    }

    fileprivate init<ID: Hashable>(id: ID,
                                   dispatcher: Dispatcher,
                                   store: Store<S>,
                                   environment: E,
                                   reducers: R)
    {
        _id = id
        _dispatcher = dispatcher
        _reducers = reducers
        _environment = environment
        _store = store
    }

    /// Set the initial store for the service.
    public func set<IS>(initialStore: Store<IS>) -> ServiceBuilder<E, IS, AnyReducers<IS>>
        where S == EmptyState, R == EmptyReducers
    {
        ServiceBuilder<E, IS, AnyReducers<IS>>(id: _id,
                                               dispatcher: _dispatcher,
                                               store: initialStore,
                                               environment: _environment,
                                               reducers: AnyReducers())
    }

    /// Sets the environment for the service.
    public func set<NE>(environment: NE) -> ServiceBuilder<NE, S, R>
        where E == EmptyEnvironment, NE: Actor
    {
        ServiceBuilder<NE, S, R>(id: _id,
                                 dispatcher: _dispatcher,
                                 store: _store,
                                 environment: environment,
                                 reducers: _reducers)
    }

    /// Adds a new reducer to the service.
    public func add<A>(reducer: Reducer<E, S, A>) -> ServiceBuilder<E, S, R>
        where A: Action, R == AnyReducers<S>
    {
        let reducer = StatefulReducer(dispatcher: _dispatcher,
                                      environment: _environment,
                                      reducer: reducer)
        return ServiceBuilder(id: _id,
                              dispatcher: _dispatcher,
                              store: _store,
                              environment: _environment,
                              reducers: _reducers + reducer)
    }

    /// Adds a new reducer to the service.
    public func add<A>(reducer: Reducer<E, S, A>) -> ServiceBuilder<E, S, AnyReducers<S>>
        where A: Action, R == EmptyReducers
    {
        let reducer = StatefulReducer(dispatcher: _dispatcher,
                                      environment: _environment,
                                      reducer: reducer)
        return ServiceBuilder<E, S, AnyReducers<S>>(id: _id,
                                                    dispatcher: _dispatcher,
                                                    store: _store,
                                                    environment: _environment,
                                                    reducers: AnyReducers([reducer]))
    }

    /// Bootstraps everything, creates and registers the service with the dispatcher.
    public func bootstrap() async
        where R == AnyReducers<S>
    {
        let service = StatefulService(store: _store,
                                      reducers: _reducers.items)
        await _dispatcher.register(_id, service: service)
    }
}

/// The service pool is a collection of services that share the same dispatcher.
public struct ServicePool<ID> where ID: Hashable
{
    /// The dispatcher shared between all the services in the pool.
    public let dispatcher: Dispatcher = .init()

    /// Starts the process of creating a new service.
    public func build(service: ID) -> ServiceBuilder<EmptyEnvironment, EmptyState, EmptyReducers>
        where ID: Hashable
    {
        ServiceBuilder(id: service,
                       dispatcher: dispatcher)
    }

    /// Removes a service from the pool.
    public func remove(service: ID) async
    {
        await dispatcher.unregister(service)
    }
}
