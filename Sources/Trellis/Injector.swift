//
//  File.swift
//
//
//  Created by Valentin Radu on 07/04/2022.
//

import Foundation
import Runtime

public typealias Dispatch = (any Action) async throws -> Void

private struct DispatchKey: EnvironmentKey {
    public static var defaultValue: Dispatch = { _ in }
}

public extension EnvironmentValues {
    internal(set) var dispatch: Dispatch {
        get { self[DispatchKey.self] }
        set { self[DispatchKey.self] = newValue }
    }
}

protocol EnvironmentConsumer {
    var environmentValues: EnvironmentValues! { get set }
}

protocol EnvironmentTransformer {
    func transformEnvironment(values: EnvironmentValues) -> EnvironmentValues
}

protocol TaskRunner {
    func run() async throws
}

public extension Service {
    func inject(environment: EnvironmentValues) throws -> ActionReceiver & Injectable {
        var environment = environment

        if let service = self as? EnvironmentTransformer {
            environment = service.transformEnvironment(values: environment)
        }

        let service = try write(environment: environment)
        
//        if let service = service as? TaskRunner {
//            try await service.run()
//        }

        if Body.self == Never.self {
            return InjectedService(head: service,
                                   body: EmptyService())
        } else {
            let body = try service.body.inject(environment: environment)
            return InjectedService(head: service,
                                   body: body)
        }
    }
    
    func write(environment: EnvironmentValues) throws -> Self {
        var service = self
        let info = try typeInfo(of: Self.self)
        for property in info.properties {
            if var value = try property.get(from: service) as? EnvironmentConsumer {
                value.environmentValues = environment
                try property.set(value: value,
                                 on: &service)
            }
        }
        return service
    }
}

public struct InjectedService: Service {
    public let head: ActionReceiver
    public let body: ActionReceiver

    public func receive(action: Action) async throws {
        try await head.receive(action: action)
        try await body.receive(action: action)
    }
}
