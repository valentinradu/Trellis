//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Combine

/**
 The dispatcher propagates actions to reducers.
 Its main jobs are:
    - to register reducers
    - to register middlewares
    - to publish actions
    - to handle redirections

 - note: All the async `publish` operations also have `Combine`, `async/await` and legacy callback closures support.
 */
public class Dispatcher {
    public typealias Completion = (Result<Void, Error>) -> Void

    /// All the actions published since the dispatcher was initiated or reseted
    public private(set) var history: ActionFlow<AnyAction> = .empty

    private var _reducers: [AnyReducer] = []
    private var _middlewares: [AnyMiddleware] = []
    private var _environment: Environment = .init()
    private var _cancellables: Set<AnyCancellable> = []

    /**
     Registers a new middleware.
     - parameter middleware: The middleware instance to register
     - seealso: Middleware
     */
    public func register<M: Middleware>(middleware: M) {
        _middlewares.append(AnyMiddleware(middleware))
    }

    /**
     Registers a new reducer
     - parameter reducer: The reducer instance to register
     - seealso: Reducer
     */
    public func register<W: Reducer>(reducer: W) {
        _reducers.append(AnyReducer(reducer))
    }

    public func register<D>(dependency: D, for key: WritableKeyPath<Environment, D>) {
        _environment[keyPath: key] = dependency
    }

    /**
     Resets the dispatcher to its initial state, stopping any current action processing and optionally unregistering the reducers, middleware and clearing the history.
     */
    public func reset(history: Bool = false,
                      reducers: Bool = false,
                      middlewares: Bool = false)
    {
        _cancellables = []
        if history {
            self.history = .empty
        }
        if reducers {
            _reducers = []
        }
        if middlewares {
            _middlewares = []
        }
    }

    /**
     Publishes an action and calls back a completion handler when the action has been processed by all the reducers.
        - parameter action: The action
     */
    func publish<A: Action>(_ action: A,
                            completion: Completion?)
    {
        _publish(action)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case let .failure(error):
                        completion?(.failure(error))
                    case .finished:
                        break
                    }
                },
                receiveValue: { result in
                    completion?(.success(result))
                }
            )
            .store(in: &_cancellables)
    }

    /**
     Publishes an action flow (multiple actions chained one after the other) and calls back a completion handler when the it has been processed by all the reducers. If any of the reducers throws an error, the chain is interruped and the remaining actions are not processed.
        - parameter flow: The action flow
     */
    public func publish<A: Action>(_ flow: ActionFlow<A>,
                                   completion: Completion?)
    {
        _publish(flow)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case let .failure(error):
                        completion?(.failure(error))
                    case .finished:
                        break
                    }
                },
                receiveValue: { result in
                    completion?(.success(result))
                }
            )
            .store(in: &_cancellables)
    }

    /**
     Publishes an action and returns a publisher that completes (or errors out) when all the reducers finished processing the action.
        - parameter action: The action
     */
    public func publish<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        _publish(action)
    }

    /**
     Publishes an action flow (multiple actions chained one after the other) and returns a publisher that completes (or errors out) when all the reducers finished processing the actions. If any of the reducers throws an error, the chain is interruped and the remaining actions are not processed anymore.
         - parameter flow: The action flow
     */
    public func publish<A: Action>(_ flow: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        _publish(flow)
    }

    /**
     Similar to the other `publish(action:)` methods, except completion is ignored.
         - parameter action: The action
         - seealso: publish(action:)
     */
    public func publishAndForget<A: Action>(_ action: A) {
        publish(action, completion: nil)
    }

    /**
     Similar to the other `publish(flow:)` methods, except completion is ignored.
        - parameter flow: The action flow
        - seealso: publish(flow:)
     */
    public func publishAndForget<A: Action>(_ flow: ActionFlow<A>) {
        publish(flow, completion: nil)
    }

    /**
     Publish an action using `async/await`
     */
    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    public func publish<A: Action>(_ action: A) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            publish(action) {
                switch $0 {
                case .success:
                    continuation.resume(returning: ())
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /**
     Publish an action flow using `async/await`
     */
    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    public func publish<A: Action>(_ flow: ActionFlow<A>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            publish(flow) {
                switch $0 {
                case .success:
                    continuation.resume(returning: ())
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension Dispatcher {
    func _publish<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        _publish(.init(actions: [action]))
    }

    func _publish<A: Action>(_ flow: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        var pub = Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()

        var stack = Array(
            flow.actions
                .map { AnyAction($0) }
        )

        while !stack.isEmpty {
            let action = stack.removeFirst()
            pub = pub
                .flatMap { [self] () -> AnyPublisher<Void, Error> in
                    for middleware in _middlewares {
                        do {
                            let rewrite = try middleware.pre(action: AnyAction(action))

                            switch rewrite {
                            case let .redirect(otherFlow):
                                let actions = otherFlow.actions + stack
                                return _publish(.init(actions: actions))
                            case .none:
                                continue
                            }
                        } catch {
                            for middleware in _middlewares {
                                middleware.failure(action: action,
                                                   error: error)
                            }
                            return Fail(outputType: Void.self,
                                        failure: error)
                                .eraseToAnyPublisher()
                        }
                    }

                    var reducerPubs: [AnyPublisher<Void, Error>] = []
                    for reducer in _reducers {
                        reducerPubs.append(
                            reducer.receive(action, environment: _environment)
                                .handleEvents(receiveCompletion: { [self] result in
                                    switch result {
                                    case let .failure(error):
                                        for middleware in _middlewares {
                                            middleware.failure(action: action, error: error)
                                        }
                                    case .finished:
                                        break
                                    }
                                })
                                .flatMap {
                                    _publish($0)
                                }
                                .share()
                                .eraseToAnyPublisher()
                        )
                    }

                    return Publishers.MergeMany(reducerPubs)
                        .collect()
                        .map { _ in () }
                        .flatMap {
                            Future<Void, Error> { promise in
                                self.history = self.history.then(action)

                                for middleware in self._middlewares {
                                    middleware.post(action: action)
                                }

                                promise(.success(()))
                            }
                            .eraseToAnyPublisher()
                        }
                        .share()
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }

        return pub
    }
}
