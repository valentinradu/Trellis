//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Combine

/**
 Workers are specialized in processing tasks when receiving specific actions. For example, you could have a worker handling authentication, other handling the server API, other persistence, and so on. The worker usually can access and modify the state of the app.
 */
public protocol Worker {
    associatedtype A: Action
    /**
     The `execute(action:)` method is called by the dispatcher when an action needs to be processed.
        - returns: A publisher that returns an action flow executed right after the current action
     */
    func execute(_ action: A) -> AnyPublisher<ActionFlow<A>, Error>
    /**
     The `execute(action:)` method is called by the dispatcher when an action needs to be processed and executed
        - returns: An action flow executed right after the current action
     */
    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    func execute(_ action: A) async throws -> ActionFlow<A>
}

public extension Worker {
    func execute(_ action: A) -> AnyPublisher<ActionFlow<A>, Error> {
        if #available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *) {
            let pub: PassthroughSubject<ActionFlow<A>, Error> = PassthroughSubject()
            Task {
                do {
                    let others = try await execute(action)
                    pub.send(others)
                    pub.send(completion: .finished)
                } catch {
                    pub.send(completion: .failure(error))
                }
            }

            return pub
                .eraseToAnyPublisher()
        } else {
            return Just(.empty())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    func execute(_: A) async throws -> ActionFlow<AnyAction> {
        return .empty()
    }
}

/**
 Worker type erasure
 */
public struct AnyWorker: Worker {
    public typealias A = AnyAction
    private let executeClosure: (AnyAction) -> AnyPublisher<ActionFlow<A>, Error>

    public init<W: Worker>(_ source: W) {
        executeClosure = {
            if let action = $0.wrappedValue as? W.A {
                return source.execute(action)
                    .map {
                        ActionFlow(actions: $0.actions.map { AnyAction($0) })
                    }
                    .eraseToAnyPublisher()
            } else {
                return Just(.empty())
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        }
    }

    public func execute(_ action: A) -> AnyPublisher<ActionFlow<A>, Error> {
        executeClosure(action)
    }
}
