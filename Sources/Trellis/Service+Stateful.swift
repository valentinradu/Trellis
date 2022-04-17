//
//  File.swift
//
//
//  Created by Valentin Radu on 16/04/2022.
//

import Foundation

private struct ModelKey: EnvironmentKey {
    static var defaultValue: Actor? = nil
}

private typealias AnyMutation = (Actor, any Action) async throws -> Void
private struct MutationsKey: EnvironmentKey {
    static var defaultValue: [AnyMutation] = []
}

private extension EnvironmentValues {
    var model: Actor? {
        get { self[ModelKey.self] }
        set { self[ModelKey.self] = newValue }
    }

    var mutations: [AnyMutation] {
        get { self[MutationsKey.self] }
        set { self[MutationsKey.self] = newValue }
    }
}

public typealias Mutation<S, A> = (S, A) async throws -> Void where A: Action, S: Actor

public extension Service {
    func model<S>(_ model: S) -> some Service where S: Actor {
        environment(\.model, value: model)
    }

    func mutate<S, A>(model _: S.Type,
                      on _: A.Type,
                      _ closure: @escaping Mutation<S, A>) -> some Service
        where A: Action, S: Actor
    {
        let receiver: AnyMutation = {
            if let action = $1 as? A,
               let store = $0 as? S
            {
                try await closure(store, action)
            }
        }

        return transformEnvironment(\.mutations) {
            $0 + [receiver]
        }
    }
}

public struct Store: Service {
    @Environment(\.model) private var _model
    @Environment(\.mutations) private var _mutations

    public var body: some Service {
        EmptyService()
            .observe {
                for receiver in _mutations {
                    if let model = _model {
                        try await receiver(model, $0)
                    }
                }
            }
    }
}
