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

private extension EnvironmentValues {
    var model: Any? {
        get { self[ModelKey.self] }
        set { self[ModelKey.self] = newValue }
    }
}

public typealias Mutation<S, A> = (inout S, A, Send) async throws -> Void where A: Action

public extension Service {
    func with<S>(model: S) -> some Service {
        environment(\.model, value: model)
    }
}

private typealias AnyMutation = (Any, any Action, Send) async throws -> Void
public struct Store<S>: Service {
    @Environment(\.model) private var _model
    @Environment(\.send) private var _send
    private let _mutations: [AnyMutation]

    public typealias Body = Never

    public init(model _: S.Type) {
        _mutations = []
    }

    private init(model _: S.Type, mutations: [AnyMutation]) {
        _mutations = mutations
    }

    public func receive(action: any Action) async throws {
        for receiver in _mutations {
            if let model = _model {
                try await receiver(model, action, _send)
            }
        }
    }

    public func mutate<A>(on _: A.Type,
                          _ closure: @escaping Mutation<S, A>) -> Self
        where A: Action
    {
        let receiver: AnyMutation = {
            if let action = $1 as? A,
               var store = $0 as? S
            {
                try await closure(&store, action, $2)
            }
        }

        return Store(model: S.self,
                     mutations: _mutations + [receiver])
    }
}
