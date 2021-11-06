import Combine

public protocol Worker {
    associatedtype A: Action
    func execute(_ action: A) -> AnyPublisher<Void, Error>
    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func execute(_ action: A) async throws
}

public extension Worker {
    func execute(_ action: A) -> AnyPublisher<Void, Error> {
        if #available(iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
            let pub: PassthroughSubject<Void, Error> = PassthroughSubject()
            Task {
                do {
                    try await execute(action)
                    pub.send()
                    pub.send(completion: .finished)
                } catch {
                    pub.send(completion: .failure(error))
                }
            }

            return pub
                .eraseToAnyPublisher()
        } else {
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }

    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func execute(_: A) async throws {}
}

public protocol Middleware {
    associatedtype A: Action
    func pre(action: A) throws -> Rewrite<A>
    func post(action: A)
    func failure(action: A, error: Error)
}

public struct AnyMiddleware: Middleware {
    public typealias A = AnyAction
    private let preClosure: (AnyAction) throws -> Any
    private let postClosure: (AnyAction) -> Void
    private let failureClosure: (AnyAction, Error) -> Void

    public init<M: Middleware>(_ source: M) {
        preClosure = {
            if let action = $0 as? M.A {
                return try source.pre(action: action)
            }
            return Rewrite<M.A>.none
        }

        postClosure = {
            if let action = $0 as? M.A {
                source.post(action: action)
            }
        }

        failureClosure = {
            if let action = $0 as? M.A {
                source.failure(action: action, error: $1)
            }
        }
    }

    public func pre(action: A) throws -> Rewrite<A> {
        try preClosure(action) as? Rewrite<A> ?? .none
    }

    public func post(action: A) {
        postClosure(action)
    }

    public func failure(action: A, error: Error) {
        failureClosure(action, error)
    }
}

public extension Middleware {
    func pre(action _: A) -> Rewrite<A> {
        .none
    }

    func post(action _: A) {}
    func failure(action _: A, error _: Error) {}
}

public enum Rewrite<A: Action> {
    public struct DeferOptions {
        let lookBehind: Bool
        let enqueueSimilarEvents: Bool

        public init(lookBehind: Bool = false,
                    enqueueSimilarEvents: Bool = false)
        {
            self.lookBehind = lookBehind
            self.enqueueSimilarEvents = enqueueSimilarEvents
        }
    }

    case none
    case redirect(to: A)
    case `defer`(until: A.Name, options: DeferOptions = .init())
}

public struct AnyWorker: Worker {
    public typealias A = AnyAction
    private let executeClosure: (AnyAction) -> AnyPublisher<Void, Error>

    public init<W: Worker>(_ source: W) {
        executeClosure = {
            if let action = $0 as? W.A {
                return source.execute(action)
            } else {
                return Just(())
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        }
    }

    public func execute(_ action: A) -> AnyPublisher<Void, Error> {
        executeClosure(action)
    }
}

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
