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
public class EmptyState {}

/// The empty reducer placeholder.
public struct EmptyReducer {}

/// The service builder for bootstrapping services. This is usually created by the service pool.
public struct ServiceBuilder<N, S, R>
    where N: ServiceName
{
    private let _name: N
    private let _dispatch: ServiceDispatch
    private let _state: S
    private let _reducers: R

    fileprivate init(name: N,
                     dispatch: ServiceDispatch)
        where S == EmptyState, R == [EmptyReducer]
    {
        _name = name
        _dispatch = dispatch
        _reducers = [EmptyReducer]()
        _state = EmptyState()
    }

    fileprivate init(name: N,
                     dispatch: ServiceDispatch,
                     state: S,
                     reducers: R)
    {
        _name = name
        _dispatch = dispatch
        _reducers = reducers
        _state = state
    }

    /// Set the initial state for the service.
    public func add<IS>(state: IS) -> ServiceBuilder<N, IS, R>
        where S == EmptyState, R == [EmptyReducer]
    {
        ServiceBuilder<N, IS, R>(name: _name,
                                 dispatch: _dispatch,
                                 state: state,
                                 reducers: _reducers)
    }

    /// Adds a new reducer to the service.
    public func add<E, A>(reducer: @escaping Reducer<E, S, A>,
                          environment: E) -> ServiceBuilder<N, S, [StatefulReducer<S>]>
        where R == [EmptyReducer], A: Action
    {
        let reducer = StatefulReducer(dispatch: _dispatch,
                                      environment: environment,
                                      reducer: reducer)
        return ServiceBuilder<N, S, [StatefulReducer<S>]>(name: _name,
                                                          dispatch: _dispatch,
                                                          state: _state,
                                                          reducers: [reducer])
    }

    /// Adds a new reducer to the service.
    public func add<E, A>(reducer: @escaping Reducer<E, S, A>,
                          environment: E) -> ServiceBuilder<N, S, R>
        where R == [StatefulReducer<S>], A: Action
    {
        let reducer = StatefulReducer(dispatch: _dispatch,
                                      environment: environment,
                                      reducer: reducer)
        return ServiceBuilder<N, S, R>(name: _name,
                                       dispatch: _dispatch,
                                       state: _state,
                                       reducers: _reducers + [reducer])
    }

    /// Bootstraps everything, creates and registers the service with the dispatch.
    public func bootstrap() async
        where R == [StatefulReducer<S>]
    {
        let service = StatefulService(state: _state,
                                      reducers: _reducers)
        await _dispatch.registerService(service, name: _name)
    }
}

/// The service pool is a collection of services that share the same dispatch.
public struct ServicePool<N> where N: ServiceName
{
    /// The dispatch function
    public var dispatch: Dispatch { _dispatch }
    @MainActor public var hasTasks: Bool { _dispatch.hasTasks }

    private let _dispatch: ServiceDispatch

    public init()
    {
        _dispatch = ServiceDispatch()
    }

    /// Starts the process of creating a new service.
    public func build(service: N) -> ServiceBuilder<N, EmptyState, [EmptyReducer]>
        where N: ServiceName
    {
        ServiceBuilder(name: service,
                       dispatch: _dispatch)
    }

    /// Removes a service from the pool.
    public func remove(service: N) async
    {
        await _dispatch.unregisterService(service)
    }

    public func waitForAllTasks() async
    {
        await _dispatch.waitForAllTasks()
    }
}
