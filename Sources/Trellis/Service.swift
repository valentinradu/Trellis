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

public protocol ActionSendable {
    func send<ID>(action: any Action, from: ID) async throws
        where ID: Identity
}

public protocol Injectable {
    @MainActor func inject<ID>(environment: EnvironmentValues,
                               from: ID) async throws
        where ID: Identity
}

public protocol Service: ActionSendable, Injectable {
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
    func send<ID>(action: any Action, from parentId: ID) async throws
        where ID: Identity
    {
        let id = identity(from: parentId)
        if let environment = EnvironmentValues.all[id] {
            try write(environment: environment, id: id)
        }

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
        try write(environment: environment, id: id)

        if Body.self != Never.self {
            try await body.inject(environment: environment,
                                  from: id)
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
        EnvironmentValues.all[id] = environment
    }

    func write<ID>(environment: EnvironmentValues, id: ID) throws
        where ID: Identity
    {
        let info = try typeInfo(of: Self.self)
        for (i, property) in info.properties.enumerated() {
            let value = try property.get(from: self)
            if let value = value as? EnvironmentConsumer {
                value.environmentValues.value = environment
            }
            if let value = value as? StateConsumer {
                value.id.value = (id, i)
            }
        }
    }
}

class MutableRef<I> {
    var value: I
    init(_ value: I) {
        self.value = value
    }
}
