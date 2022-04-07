//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public typealias Dispatch = (any Action) async throws -> Void

private struct DispatchKey: EnvironmentKey {
    public static var defaultValue: Dispatch = { _ in }
}

public extension EnvironmentValues {
    private(set) var dispatch: Dispatch {
        get { self[DispatchKey.self] }
        set { self[DispatchKey.self] = newValue }
    }
}

public class Cluster<I>: Service
    where I: Service
{
    private var _items: I
    public init(@ServiceBuilder _ itemsBuilder: () -> I) {
        _items = itemsBuilder()
    }

    public var body: some Service {
        _items
    }
}
