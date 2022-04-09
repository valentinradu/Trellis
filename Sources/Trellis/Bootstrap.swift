//
//  File.swift
//
//
//  Created by Valentin Radu on 07/04/2022.
//

import Foundation

public struct Bootstrap {
    private var _node: Node
    public init<I>(@ServiceBuilder _ itemsBuilder: () -> I) throws
        where I: Service
    {
        _node = try Node(itemsBuilder(),
                         environmentValues: EnvironmentValues())
    }

    public func send(action: any Action) async throws {
        try await _node.receive(action: action)
    }
}
