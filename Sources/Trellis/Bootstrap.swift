//
//  File.swift
//
//
//  Created by Valentin Radu on 07/04/2022.
//

import Foundation

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

public struct Bootstrap<I>
    where I: Service
{
    private let rootHashValue: Int = UUID().hashValue
    private var _items: I
    public init(@ServiceBuilder _ itemsBuilder: () -> I) async throws {
        _items = itemsBuilder()
        var environment = EnvironmentValues()
        environment.dispatch = send
        try await _items
            .inject(environment: environment,
                    from: rootHashValue)
    }

    public func send(action: any Action) async throws {
        try await _items.send(action: action,
                              from: rootHashValue)
    }
}
