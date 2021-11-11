//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Combine

/// The name of each store used by the dispatcher
public enum ActionStoreName {
    /// The name of the store holding all the operations that await on another specific operation to fire
    case shelf
    /// The name of the store holding all the operations that fired since the dispatcher's initialization
    case ledger
}

/**
 The dispatcher propagates actions to each worker.
 Its main jobs are:
    - register workers
    - fire actions
    - handle action redirection and deferral
    - purge the history (`.ledger`) and deferred action queue (`.shelf`)

 - note: All the async `fire` operations have `Combine`, `async/await` and legacy callback closures support.
 */
public class Dispatcher {
    public typealias Completion = (Result<Void, Error>) -> Void
    private var _workers: [AnyWorker] = []
    private var _middlewares: [AnyMiddleware] = []
    private var _cancellables: Set<AnyCancellable> = []
    private var _ledger: [AnyAction] = []
    private var _shelf: [AnyAction.Name: [AnyAction]] = [:]

    /**
     Registers a new middleware.
     - parameter middleware: The middleware instance to register
     - seealso: Middleware
     */
    public func register<M: Middleware>(middleware: M) {
        _middlewares.append(AnyMiddleware(middleware))
    }

    /**
     Registers a new worker
     - parameter worker: The worker instance to register
     - seealso: Worker
     */
    public func register<W: Worker>(worker: W) {
        _workers.append(AnyWorker(worker))
    }

    /**
     The dispatcher is mostly stateless and it can be used in any context without reinitialization. However, it does store the history (`.ledger`) and the actions that are waiting on other actions to fire (`.shelf`). `purge(from:)` clears any of these specific stores for cases when this is required (e.g. logging out an user, resetting your state, etc ).
        - parameter from: The name of the store that will be cleared (`.shelf` or `.ledger`)
     */
    public func purge(from: ActionStoreName) {
        switch from {
        case .ledger:
            _ledger = []
        case .shelf:
            _shelf = [:]
        }
    }

    /**
     Purges all actions from all the stores. This is similar to reinitializing the dispatcher, but without having to register the workers again.
     */
    public func purge() {
        _shelf = [:]
        _ledger = []
    }

    /**
     Fires an action and calls back a completion handler when the action has been processed by all the workers.
        - parameter action: The action
     */
    func fire<A: Action>(_ action: A,
                         completion: Completion?)
    {
        _fire(action)
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
     Fires an action flow (multiple actions chained one after the other) and calls back a completion handler when the it has been processed by all the workers. If any of the workers throws an error, the chain is interruped and the remaining actions are not processed anymore.
        - parameter flow: The action flow
     */
    public func fire<A: Action>(_ flow: ActionFlow<A>,
                                completion: Completion?)
    {
        _fire(flow)
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
     Fires an action and returns a publisher that completes (or errors out) when all the workers finished processing the action.
        - parameter action: The action
     */
    public func fire<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        _fire(action)
    }

    /**
      Fires an action flow (multiple actions chained one after the other) and returns a publisher that completes (or errors out) when all the workers finished processing the actions. If any of the workers throws an error, the chain is interruped and the remaining actions are not processed anymore.
         - parameter flow: The action flow
     */
    public func fire<A: Action>(_ flow: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        _fire(flow)
    }

    /**
     Similar to the other `fire(action:)` methods, except completion is ignored.
         - parameter action: The action
         - seealso: fire(action:)
     */
    public func fireAndForget<A: Action>(_ action: A) {
        fire(action, completion: nil)
    }

    /**
     Similar to the other `fire(flow:)` methods, except completion is ignored.
        - parameter flow: The action flow
        - seealso: fire(flow:)
     */
    public func fireAndForget<A: Action>(_ flow: ActionFlow<A>) {
        fire(flow, completion: nil)
    }

    /**
     Fires an action using `async/await`
     */
    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func fire<A: Action>(_ action: A) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            fire(action) {
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
     Fires an action flow using `async/await`
     */
    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func fire<A: Action>(_ flow: ActionFlow<A>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            fire(flow) {
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
    func _fire<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        var action = AnyAction(action)
        do {
            for middleware in _middlewares {
                let rewrite = try middleware.pre(action: action)

                switch rewrite {
                case let .redirect(newAction):
                    action = newAction
                case let .defer(queue):
                    if options.lookBehind, _ledger.map(\.name).contains(name) {
                        continue
                    } else {
                        if _shelf[name] == nil {
                            _shelf[name] = []
                        }

                        if options.enqueueSimilarEvents {
                            _shelf[name]!.append(action)
                        } else {
                            if !_shelf[name]!.contains(where: { $0.name == action.name }) {
                                _shelf[name]!.append(action)
                            }
                        }
                    }
                case .none:
                    continue
                }

                break
            }

            var pubs: [AnyPublisher<Void, Error>] = []

            for worker in _workers {
                pubs.append(worker.execute(action))
            }

            return Publishers.MergeMany(pubs)
                .collect()
                .map { _ in () }
                .flatMap {
                    Future<[AnyAction]?, Error> { promise in
                        self._ledger.append(action)

                        for middleware in self._middlewares {
                            middleware.post(action: action)
                        }

                        if let deps = self._shelf.removeValue(forKey: action.name) {
                            promise(.success(deps))
                        } else {
                            promise(.success(nil))
                        }
                    }
                    .eraseToAnyPublisher()
                }
                .flatMap { deps -> AnyPublisher<Void, Error> in
                    if let deps = deps {
                        var pubs: [AnyPublisher<Void, Error>] = []

                        for dep in deps {
                            pubs.append(self._fire(dep))
                        }

                        return Publishers.MergeMany(pubs)
                            .collect()
                            .map { _ in () }
                            .eraseToAnyPublisher()
                    } else {
                        return Just(())
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                }
                .share()
                .eraseToAnyPublisher()
        } catch {
            return Fail(outputType: Void.self,
                        failure: error)
                .eraseToAnyPublisher()
        }
    }

    func _fire<A: Action>(_ flow: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        if let first = flow.actions.first {
            var pub = _fire(first)
            for action in flow.actions[1...] {
                pub = pub
                    .flatMap {
                        self._fire(action)
                    }
                    .eraseToAnyPublisher()
            }

            return pub
        } else {
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
}
