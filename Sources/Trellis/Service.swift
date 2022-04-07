//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

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

public protocol Service: NodeBuilder {
    associatedtype Body where Body: Service
    @ServiceBuilder var body: Body { get }
    func receive(action _: any Action) async throws
}

public extension Service {
    func receive(action _: any Action) async throws {}

    func buildBody(in node: Node) throws {
        if Body.self != Never.self {
            try node.addChild(body)
        }
    }

    func transform(environment _: inout EnvironmentValues) {}
}

public extension Service where Body == Never {
    var body: Never { fatalError() }
}

extension Never: Service {
    public var body: Never { fatalError() }
}

public struct EmptyService: Service {
    public typealias Body = Never
}

extension EmptyService: NodeBuilder {}
