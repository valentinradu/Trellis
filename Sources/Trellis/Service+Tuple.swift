//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation
import Runtime

public struct _TupleService: Service {
    @Environment(\.concurrencyStrategy) private var _concurrencyStrategy
    @Environment(\.failureStrategy) private var _failureStrategy
    @Environment(\.dispatch) private var _dispatch

    private var _children: [any ActionReceiver & Injectable]

    init<A0>(_ value: A0?)
        where A0: Service
    {
        if let value = value {
            _children = [value]
        } else {
            _children = []
        }
    }

    init<A0>(_ value: A0)
        where A0: Service
    {
        _children = [value]
    }

    init<A0, A1>(_ tuple: (A0, A1))
        where A0: Service, A1: Service
    {
        _children = [
            tuple.0,
            tuple.1,
        ]
    }

    init<A0, A1, A2>(_ tuple: (A0, A1, A2))
        where A0: Service, A1: Service, A2: Service
    {
        _children = [
            tuple.0,
            tuple.1,
            tuple.2,
        ]
    }

    init<A0, A1, A2, A3>(_ tuple: (A0, A1, A2, A3))
        where A0: Service, A1: Service, A2: Service, A3: Service
    {
        _children = [
            tuple.0,
            tuple.1,
            tuple.2,
            tuple.3,
        ]
    }

    init<A0, A1, A2, A3, A4>(_ tuple: (A0, A1, A2, A3, A4))
        where A0: Service, A1: Service, A2: Service, A3: Service, A4: Service
    {
        _children = [
            tuple.0,
            tuple.1,
            tuple.2,
            tuple.3,
            tuple.4,
        ]
    }

    init<A0, A1, A2, A3, A4, A5>(_ tuple: (A0, A1, A2, A3, A4, A5))
        where A0: Service, A1: Service, A2: Service, A3: Service,
        A4: Service, A5: Service
    {
        _children = [
            tuple.0,
            tuple.1,
            tuple.2,
            tuple.3,
            tuple.4,
            tuple.5,
        ]
    }

    init<A0, A1, A2, A3, A4, A5, A6>(_ tuple: (A0, A1, A2, A3, A4, A5, A6))
        where A0: Service, A1: Service, A2: Service, A3: Service,
        A4: Service, A5: Service, A6: Service
    {
        _children = [
            tuple.0,
            tuple.1,
            tuple.2,
            tuple.3,
            tuple.4,
            tuple.5,
            tuple.6,
        ]
    }

    init<A0, A1, A2, A3, A4, A5, A6, A7>(_ tuple: (A0, A1, A2, A3, A4, A5, A6, A7))
        where A0: Service, A1: Service, A2: Service, A3: Service,
        A4: Service, A5: Service, A6: Service, A7: Service
    {
        _children = [
            tuple.0,
            tuple.1,
            tuple.2,
            tuple.3,
            tuple.4,
            tuple.5,
            tuple.6,
            tuple.7,
        ]
    }

    public func inject(environment: EnvironmentValues) throws -> ActionReceiver & Injectable {
        var service = try write(environment: environment)

        service._children = try _children.compactMap {
            try $0.inject(environment: environment)
        }

        return InjectedService(head: service,
                               body: EmptyService())
    }

    public func receive(action: any Action) async throws {
        switch _concurrencyStrategy {
        case .concurrent:
            switch _failureStrategy {
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
            switch _failureStrategy {
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
