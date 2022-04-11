//
//  File.swift
//
//
//  Created by Valentin Radu on 07/04/2022.
//

import Foundation

public struct Bootstrap {
    private var _items: ActionReceiver?
    public init<I>(@ServiceBuilder _ itemsBuilder: () -> I) async throws
        where I: Service
    {
        var environment = EnvironmentValues()
        environment.dispatch = send
        let items = try itemsBuilder().inject(environment: environment)
        _items = items
    }

    public func send(action: any Action) async throws {
        try await _items?.receive(action: action)
    }
}
