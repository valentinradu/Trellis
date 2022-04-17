//
//  File.swift
//
//
//  Created by Valentin Radu on 16/04/2022.
//

import Foundation

private typealias AnyMutation = (Any, any Action) async throws -> Void
private struct MutationsKey: EnvironmentKey {
    static var defaultValue: [AnyMutation] = []
}

private extension EnvironmentValues {
    var mutations: [AnyMutation] {
        get { self[MutationsKey.self] }
        set { self[MutationsKey.self] = newValue }
    }
}

public typealias Mutation<S, A> = (S, A, Send) async throws -> Void where A: Action

public extension Service {
    func with<M>(model: M) -> some Service
        where M: AnyObject
    {
        environmentObject(model)
    }
}

public struct Store<M>: Service
where M: AnyObject
{
    @EnvironmentObject private var _model: M
    @Environment(\.mutations) private var _mutations
    @Environment(\.send) private var _send

    public init(model _: M.Type) {}

    public var body: some Service {
        EmptyService()
            .observe {
                for receiver in _mutations {
                    try await receiver(_model, $0)
                }
            }
    }

    public func mutate<A>(on _: A.Type,
                          _ closure: @escaping Mutation<M, A>) -> some Service
        where A: Action
    {
        let receiver: AnyMutation = {
            if let action = $1 as? A,
               let store = $0 as? M
            {
                try await closure(store, action, _send)
            }
        }

        return transformEnvironment(\.mutations) {
            $0 + [receiver]
        }
    }
}
