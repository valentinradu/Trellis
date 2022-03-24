//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

public actor EmptyEnvironment {}

public struct EmptyState {}

public struct ServiceBuilder<E, S> where E: Actor
{
    private let _id: AnyHashable
    private let _dispatcher: Dispatcher
    private let _store: Store<S>
    private let _environment: E
    private let _reducers: [ReducerContext<S>]

    fileprivate init<ID: Hashable>(id: ID,
                                   dispatcher: Dispatcher)
        where S == EmptyState, E == EmptyEnvironment
    {
        _id = id
        _dispatcher = dispatcher
        _reducers = []
        _environment = EmptyEnvironment()
        _store = Store(EmptyState())
    }

    fileprivate init<ID: Hashable>(id: ID,
                                   dispatcher: Dispatcher,
                                   store: Store<S>,
                                   environment: E,
                                   reducers: [ReducerContext<S>])
    {
        _id = id
        _dispatcher = dispatcher
        _reducers = reducers
        _environment = environment
        _store = store
    }

    public func set(store: Store<S>) -> ServiceBuilder<E, S>
        where S == EmptyState
    {
        ServiceBuilder(id: _id,
                       dispatcher: _dispatcher,
                       store: store,
                       environment: _environment,
                       reducers: _reducers)
    }

    public func set<NE>(environment: NE) -> ServiceBuilder<NE, S>
        where E == EmptyEnvironment, NE: Actor
    {
        ServiceBuilder<NE, S>(id: _id,
                              dispatcher: _dispatcher,
                              store: _store,
                              environment: environment,
                              reducers: _reducers)
    }

    public func add<A>(reducer: Reducer<E, S, A>) -> ServiceBuilder<E, S>
        where A: Action
    {
        let reducer = ReducerContext(dispatcher: _dispatcher,
                                     environment: _environment,
                                     reducer: reducer)
        return ServiceBuilder(id: _id,
                              dispatcher: _dispatcher,
                              store: _store,
                              environment: _environment,
                              reducers: _reducers + [reducer])
    }

    public func bootstrap() async
    {
        let service = StatefulService(store: _store,
                                      reducers: _reducers)
        await _dispatcher.register(_id, service: service)
    }
}

public struct ServicePool<ID> where ID: Hashable
{
    public let dispatcher: Dispatcher = .init()

    public func createService(id: ID) -> ServiceBuilder<EmptyEnvironment, EmptyState>
        where ID: Hashable
    {
        ServiceBuilder(id: id,
                       dispatcher: dispatcher)
    }

    public func destroyService(id: ID) async
    {
        await dispatcher.unregister(id)
    }
}
