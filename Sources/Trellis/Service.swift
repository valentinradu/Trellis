//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation
import Runtime

/**
 Reducers react to **actions** and mutate the state in a predictable way.
 ```
 enum AccountAction: Action {
     case login(email: String, password: String)
     case logout
     case resetPassword
 }
 ```
 */

public protocol Action {}

public protocol Identity: Hashable {}

extension AnyHashable: Identity {}

public protocol ActionReceiver {
    func send<ID>(action: any Action, from: ID) async throws where ID: Identity
    func receive(action: any Action) async throws
}

public protocol Injectable {
    @MainActor func inject<ID>(environment: EnvironmentValues, from: ID) async throws where ID: Identity
}

public protocol Service: ActionReceiver, Injectable {
    associatedtype Body where Body: Service
    @ServiceBuilder var body: Body { get }
}

public extension Service where Body == Never {
    var body: Never { fatalError() }
}

extension Never: Service {
    public var body: Never { fatalError() }
}

public struct EmptyService: Service {
    public var body: Never { fatalError() }
}

public extension Service {
    func receive(action _: any Action) async throws {}

    func send<ID>(action: any Action, from parentId: ID) async throws
        where ID: Identity
    {
        let id = identity(from: parentId)
        try fetchEnvironment(id: id)
        try await receive(action: action)

        if Body.self != Never.self {
            try await body.send(action: action,
                                from: id)
        }
    }

    func inject<ID>(environment: EnvironmentValues,
                    from parentId: ID) async throws
        where ID: Identity
    {
        var environment = environment
        environment.id = parentId

        let id = identity(from: parentId)
        try store(environment: environment, id: id)
        try fetchEnvironment(id: id)

        if Body.self != Never.self {
            try await body.inject(environment: environment,
                                  from: id)
        }

        if let bootstrap = environment.bootstrap {
            try await bootstrap()
        }
    }

    func identity<ID>(from parentId: ID) -> some Identity
        where ID: Identity
    {
        var hasher = Hasher()
        hasher.combine(parentId)
        hasher.combine(ObjectIdentifier(Self.self))
        return AnyHashable(hasher.finalize())
    }

    func store<ID>(environment: EnvironmentValues,
                   id: ID) throws
        where ID: Identity
    {
        EnvironmentValues.environments[id] = environment
    }

    func fetchEnvironment<ID>(id: ID) throws
        where ID: Identity
    {
        let environment = EnvironmentValues.environments[id]
        let info = try typeInfo(of: Self.self)
        for property in info.properties {
            if let value = try property.get(from: self) as? EnvironmentConsumer {
                value.environmentValues.value = environment
            }
        }
    }
}
