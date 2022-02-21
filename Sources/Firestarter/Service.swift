//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Combine

/**
 Services are specialized in processing tasks when receiving specific actions.
 */
public protocol Service {
    associatedtype A: Action
    /**
     The `receive(action:)` method is called by the dispatcher when an action needs to be processed.
        - parameter action: The received action
        - returns: A publisher that returns an action flow received right after the current action
     */
    func receive(_ action: A) -> AnyPublisher<ActionFlow<AnyAction>, Error>
    /**
     The `receive(action:)` method is called by the dispatcher when an action needs to be processed and received
        - parameter action: The received action
        - returns: An action flow received right after the current action
     */
    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    func receive(_ action: A) async throws -> ActionFlow<AnyAction>
}

public extension Service {
    func receive(_ action: A) -> AnyPublisher<ActionFlow<AnyAction>, Error> {
        if #available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *) {
            let pub: PassthroughSubject<ActionFlow<AnyAction>, Error> = PassthroughSubject()
            Task {
                do {
                    let others = try await receive(action)
                    pub.send(others)
                    pub.send(completion: .finished)
                } catch {
                    pub.send(completion: .failure(error))
                }
            }

            return pub
                .eraseToAnyPublisher()
        } else {
            return Just(.noop)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    func receive(_: A) async throws -> ActionFlow<AnyAction> {
        return .noop
    }
}

/**
 Service type erasure
 */
public struct AnyService: Service {
    public typealias A = AnyAction
    private let receiveClosure: (AnyAction) -> AnyPublisher<ActionFlow<A>, Error>

    public init<W: Service>(_ source: W) {
        receiveClosure = {
            if let action = $0.wrappedValue as? W.A
            {
                return source.receive(action)
                    .map {
                        ActionFlow(actions: $0.actions.map { AnyAction($0) })
                    }
                    .eraseToAnyPublisher()
            } else {
                return Just(.noop)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        }
    }

    public func receive(_ action: A) -> AnyPublisher<ActionFlow<A>, Error> {
        receiveClosure(action)
    }
}
