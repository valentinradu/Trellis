//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Combine

public enum ActionStoreName {
    case queue
    case history
}

public class Dispatcher {
    public typealias Completion = (Result<Void, Error>) -> Void
    private var workers: [AnyWorker] = []
    private var middlewares: [AnyMiddleware] = []
    private var cancellables: Set<AnyCancellable> = []
    private var history: [AnyAction] = []
    private var deps: [AnyAction.Name: [AnyAction]] = [:]

    public func register<M: Middleware>(middleware: M) {
        middlewares.append(AnyMiddleware(middleware))
    }

    public func register<W: Worker>(worker: W) {
        workers.append(AnyWorker(worker))
    }

    public func purge(from: ActionStoreName) {
        switch from {
        case .history:
            history = []
        case .queue:
            deps = [:]
        }
    }

    public func purge() {
        deps = [:]
        history = []
    }

    public func fire<A: Action>(_ action: A,
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
            .store(in: &cancellables)
    }

    public func fire<A: Action>(_ action: ActionFlow<A>,
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
            .store(in: &cancellables)
    }

    public func fire<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        _fire(action)
    }

    public func fire<A: Action>(_ action: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        _fire(action)
    }

    public func fireAndForget<A: Action>(_ action: A) {
        fire(action, completion: nil)
    }

    public func fireAndForget<A: Action>(_ action: ActionFlow<A>) {
        fire(action, completion: nil)
    }

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

    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func fire<A: Action>(_ action: ActionFlow<A>) async throws {
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
}

private extension Dispatcher {
    func _fire<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        var action = AnyAction(action)
        do {
            for middleware in middlewares {
                let rewrite = try middleware.pre(action: action)

                switch rewrite {
                case let .redirect(newAction):
                    action = newAction
                case let .defer(name, options):
                    if options.lookBehind, history.map(\.name).contains(name) {
                        continue
                    } else {
                        if deps[name] == nil {
                            deps[name] = []
                        }

                        if options.enqueueSimilarEvents {
                            deps[name]!.append(action)
                        } else {
                            if !deps[name]!.contains(where: { $0.name == action.name }) {
                                deps[name]!.append(action)
                            }
                        }
                    }
                case .none:
                    continue
                }

                break
            }

            var pubs: [AnyPublisher<Void, Error>] = []

            for worker in workers {
                pubs.append(worker.execute(action))
            }

            return Publishers.MergeMany(pubs)
                .collect()
                .map { _ in () }
                .flatMap {
                    Future<[AnyAction]?, Error> { promise in
                        self.history.append(action)

                        for middleware in self.middlewares {
                            middleware.post(action: action)
                        }

                        if let deps = self.deps.removeValue(forKey: action.name) {
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
