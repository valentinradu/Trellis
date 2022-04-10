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

public protocol CustomServiceBuilder {
    func build(in node: inout Node) async throws
}

public protocol CustomBootstrap {
    mutating func bootstrap() async throws
}

protocol EnvironmentConsumer {
    var environmentValues: EnvironmentValues { get set }
}

protocol EnvironmentTransformer {
    func transformEnvironment(values: inout EnvironmentValues)
}

public struct Node {
    private typealias Receive = (any Action) async throws -> Void
    private var _environmentValues: EnvironmentValues
    private var _receive: Receive?
    private var _children: [Node]

    init<S>(_ service: S,
            environmentValues: EnvironmentValues) async throws
        where S: Service
    {
        var service = service

        _children = []
        _environmentValues = environmentValues

        if let service = service as? EnvironmentTransformer {
            service.transformEnvironment(values: &_environmentValues)
        }

        _environmentValues.dispatch = receive

        if let service = service as? CustomServiceBuilder {
            try await service.build(in: &self)
        } else if S.Body.self != Never.self {
            try await addChild(service.body)
        }

        let info = try typeInfo(of: S.self)
        for property in info.properties {
            if var value = try property.get(from: service) as? EnvironmentConsumer {
                value.environmentValues = _environmentValues
                try property.set(value: value,
                                 on: &service)
            }
        }

        if var service = service as? CustomBootstrap & ActionReceiver {
            try await service.bootstrap()
            _receive = service.receive
        } else {
            _receive = service.receive
        }
    }

    mutating func addChild<S>(_ service: S) async throws
        where S: Service
    {
        let node = try await Node(service,
                                  environmentValues: _environmentValues)
        _children.append(node)
    }

    func receive(action: any Action) async throws {
        try await _receive?(action)

        switch _environmentValues.concurrencyStrategy {
        case .concurrent:
            switch _environmentValues.failureStrategy {
            case .fail:
                try await withThrowingTaskGroup(of: Void.self) { [_children] group in
                    for child in _children {
                        group.addTask {
                            try await child.receive(action: action)
                        }
                    }

                    try await group.waitForAll()
                }
            case let .catch(handler):
                await withThrowingTaskGroup(of: Void.self) { [_children] group in
                    for child in _children {
                        group.addTask {
                            try await child.receive(action: action)
                        }
                    }

                    while let result = await group.nextResult() {
                        if case let .failure(error) = result {
                            group.addTask {
                                try await receive(action: handler(error))
                            }
                        }
                    }
                }
            }
        case .serial:
            switch _environmentValues.failureStrategy {
            case .fail:
                for child in _children {
                    try await child.receive(action: action)
                }
            case let .catch(handler):
                for child in _children {
                    do {
                        try await child.receive(action: action)
                    } catch {
                        try await receive(action: handler(error))
                    }
                }
            }
        }
    }
}
