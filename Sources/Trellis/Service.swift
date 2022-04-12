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

public protocol ActionReceiver {
    func send(action: any Action, from: Int) async throws
    func receive(action: any Action) async throws
}

public protocol Injectable {
    @MainActor func inject(environment: EnvironmentValues, from id: Int) async throws
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

    func send(action: any Action, from parentId: Int) async throws {
        let id = getId(from: parentId)
        try fetchEnvironment(id: id)
        try await receive(action: action)

        if Body.self != Never.self {
            try await body.send(action: action, from: id)
        }
    }

    func inject(environment: EnvironmentValues, from parentId: Int) async throws {
        var environment = environment
        environment.id = parentId

        let id = getId(from: parentId)
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

    func getId(from parent: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(parent)
        hasher.combine(ObjectIdentifier(Self.self))
        return hasher.finalize()
    }

    func store(environment: EnvironmentValues, id: Int) throws {
        EnvironmentValues.environments[AnyHashable(id)] = environment
    }

    func fetchEnvironment(id: Int) throws {
        let environment = EnvironmentValues.environments[AnyHashable(id)]
        let info = try typeInfo(of: Self.self)
        for property in info.properties {
            if let value = try property.get(from: self) as? EnvironmentConsumer {
                value.environmentValues.value = environment
            }
        }
    }
}
