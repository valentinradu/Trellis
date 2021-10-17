import Combine

public class Dispatcher<A: Action> {
    public typealias Completion = (Result<Void, Error>) -> Void
    private var cancellables: Set<AnyCancellable> = []
    public private(set) var history: [A] = []

    public func fire(_ action: A,
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

    public func fire(_ action: ActionFlow<A>,
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

    public func fire(_ action: A) -> AnyPublisher<Void, Error> {
        return _fire(action)
    }

    public func fire(_ action: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        return _fire(action)
    }

    public func fireAndForget(_ action: A) {
        self.fire(action, completion: nil)
    }

    public func fireAndForget(_ action: ActionFlow<A>) {
        self.fire(action, completion: nil)
    }

    @available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func fire(_ action: A) async throws {
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
    func _fire(_ action: A) -> AnyPublisher<Void, Error> {
        return Empty(completeImmediately: true,
                     outputType: Void.self,
                     failureType: Error.self)
            .eraseToAnyPublisher()
    }

    func _fire(_ action: ActionFlow<A>) -> AnyPublisher<Void, Error> {
        return Empty(completeImmediately: true,
                     outputType: Void.self,
                     failureType: Error.self)
            .eraseToAnyPublisher()
    }
}
