import Combine

public protocol Worker {
    associatedtype A: Action
    func execute(_ action: A) -> AnyPublisher<Void, Error>
    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func execute(_ action: A) async throws
}

public extension Worker {
    func execute(_ action: A) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func execute(_ action: A) async throws {}
}

public protocol Middleware {
    associatedtype A: Action
    func redirect(action: A) -> Redirection<A>
    func `defer`(action: A) -> Deferral<A>
}

public struct AnyMiddleware {
    private let middleware: Any
    public init<W: Middleware>(_ middleware: W) {
        self.middleware = middleware
    }
}

extension Middleware {
    func redirect(action: A) -> Redirection<A> {
        .none
    }

    func `defer`(action: A) -> Deferral<A> {
        .none
    }
}

public enum Deferral<A: Action> {
    case none
    case lookBehind(name: A.Name)
    case lookAhead(name: A.Name)
}

public enum Redirection<A: Action> {
    case none
    case to(action: A)
}

public struct AnyWorker {
    private let worker: Any
    public init<W: Worker>(_ worker: W) {
        self.worker = worker
    }
}

public class Dispatcher {
    public typealias Completion = (Result<Void, Error>) -> Void
    private var workers: [AnyWorker] = []
    private var middlewares: [AnyMiddleware] = []
    private var cancellables: Set<AnyCancellable> = []
    public private(set) var history: [AnyAction] = []

    public func register<M: Middleware>(middleware: M) {
        self.middlewares.append(AnyMiddleware(middleware))
    }

    public func register<W: Worker>(worker: W) {
        self.workers.append(AnyWorker(worker))
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
            .store(in: &self.cancellables)
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
            .store(in: &self.cancellables)
    }

    public func fire<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        return _fire(action)
    }

    public func fire<A: Action>(_ action: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        return _fire(action)
    }

    public func fireAndForget<A: Action>(_ action: A) {
        self.fire(action, completion: nil)
    }

    public func fireAndForget<A: Action>(_ action: ActionFlow<A>) {
        self.fire(action, completion: nil)
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
}

private extension Dispatcher {
    func _fire<A: Action>(_ action: A) -> AnyPublisher<Void, Error> {
        return Empty(completeImmediately: true,
                     outputType: Void.self,
                     failureType: Error.self)
            .eraseToAnyPublisher()
    }

    func _fire<A: Action>(_ action: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        return Empty(completeImmediately: true,
                     outputType: Void.self,
                     failureType: Error.self)
            .eraseToAnyPublisher()
    }
}
