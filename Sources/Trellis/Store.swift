//
//  File.swift
//
//
//  Created by Valentin Radu on 16/04/2022.
//

import Foundation

private struct ModelKey: EnvironmentKey {
    static var defaultValue: Any? = nil
}

private typealias AnyMutation = (Any, any Action) async throws -> Void
private struct MutationsKey: EnvironmentKey {
    static var defaultValue: [AnyMutation] = []
}

private extension EnvironmentValues {
    var model: Any? {
        get { self[ModelKey.self] }
        set { self[ModelKey.self] = newValue }
    }

    var mutations: [AnyMutation] {
        get { self[MutationsKey.self] }
        set { self[MutationsKey.self] = newValue }
    }
}

public typealias Mutation<S, A> = (inout S, A, Send) async throws -> Void where A: Action

public extension Service {
    func with<S>(model: S) -> some Service {
        environment(\.model, value: model)
    }
}

public struct Store<S>: Service {
    @Environment(\.model) private var _model
    @Environment(\.mutations) private var _mutations
    @Environment(\.send) private var _send

    public init(model _: S.Type) {}

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

    public func mutate<A>(on _: A.Type,
                          _ closure: @escaping Mutation<S, A>) -> some Service
        where A: Action
    {
        let receiver: AnyMutation = {
            if let action = $1 as? A,
               var store = $0 as? S
            {
                try await closure(&store, action, _send)
            }
        }

        return transformEnvironment(\.mutations) {
            $0 + [receiver]
        }
    }
}
