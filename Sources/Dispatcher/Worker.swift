//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Combine

/**
 Workers are specialized in executing related actions. For example, authentication, identity, persistence or any other app-specific actions that go along together. The worker usually can access and modify the state.
 */
public protocol Worker {
    associatedtype A: Action
    /// The `execute(action:)` method is called by the dispatcher when an action needs to be processed and executed
    func execute(_ action: A) -> AnyPublisher<Void, Error>
    /// The `execute(action:)` method is called by the dispatcher when an action needs to be processed and executed
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

/**
 Worker type erasure
 */
public struct AnyWorker: Worker {
    public typealias A = AnyAction
    private let executeClosure: (AnyAction) -> AnyPublisher<Void, Error>

    public init<W: Worker>(_ source: W) {
        executeClosure = {
            if let action = $0.wrappedValue as? W.A {
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
