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

public protocol ActionReceiver {
    func receive(action: any Action) async throws
}

public protocol Injectable {
    func inject(environment: EnvironmentValues) throws -> ActionReceiver & Injectable
}

public protocol Service: ActionReceiver, Injectable {
    associatedtype Body where Body: Service
    @ServiceBuilder var body: Body { get }
}

public extension Service {
    func receive(action: any Action) async throws {}
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
