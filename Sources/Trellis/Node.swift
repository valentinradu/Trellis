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

public protocol NodeBuilder {
    func buildBody(in node: Node) throws
    func transform(environmentValues: inout EnvironmentValues)
}

public final class Node {
    private var _environmentValues: EnvironmentValues!
    private var _receive: ((any Action) async throws -> Void)!
    private var _children: [Node]

    init<S>(_ service: S,
            environmentValues: EnvironmentValues) throws
        where S: Service
    {
        _children = []

        var mutatingEnvironmentValues = environmentValues
        mutatingEnvironmentValues.dispatch = receive
        var mutatingService = service

        mutatingService.transform(environmentValues: &mutatingEnvironmentValues)

        let info = try typeInfo(of: S.self)
        for property in info.properties {
            if var value = try property.get(from: mutatingService) as? EnvironmentConsumer {
                value.environmentValues = mutatingEnvironmentValues
                try property.set(value: value,
                                 on: &mutatingService)
            }
        }

        _receive = mutatingService.receive
        _environmentValues = mutatingEnvironmentValues

        try mutatingService.buildBody(in: self)
    }

    func addChild<S>(_ service: S) throws
        where S: Service
    {
        let node = try Node(service,
                            environmentValues: _environmentValues)
        _children.append(node)
    }

    func receive(action: any Action) async throws {
        try await _receive(action)

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
                await withThrowingTaskGroup(of: Void.self) { [weak self, _children] group in
                    for child in _children {
                        group.addTask {
                            try await child.receive(action: action)
                        }
                    }

                    while let result = await group.nextResult() {
                        if case let .failure(error) = result {
                            if let self = self {
                                group.addTask {
                                    try await self.receive(action: handler(error))
                                }
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
