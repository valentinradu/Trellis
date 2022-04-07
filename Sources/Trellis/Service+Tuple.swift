//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public struct _TupleService: Service {
    @Environment(\.concurrencyStrategy) private var _concurrencyStrategy
    @Environment(\.failureStrategy) private var _failureStrategy
    @Environment(\.dispatch) private var _dispatch

    private let _buildIn: (Node) throws -> Void

    init<A0, A1>(_ tuple: (A0, A1))
        where A0: Service, A1: Service
    {
        _buildIn = { node in
            try node.addChild(tuple.0)
            try node.addChild(tuple.1)
        }
    }

    init<A0, A1, A2>(_ tuple: (A0, A1, A2))
        where A0: Service, A1: Service, A2: Service
    {
        _buildIn = { node in
            try node.addChild(tuple.0)
            try node.addChild(tuple.1)
            try node.addChild(tuple.2)
        }
    }

    init<A0, A1, A2, A3>(_ tuple: (A0, A1, A2, A3))
        where A0: Service, A1: Service, A2: Service, A3: Service
    {
        _buildIn = { node in
            try node.addChild(tuple.0)
            try node.addChild(tuple.1)
            try node.addChild(tuple.2)
            try node.addChild(tuple.3)
        }
    }

    init<A0, A1, A2, A3, A4>(_ tuple: (A0, A1, A2, A3, A4))
        where A0: Service, A1: Service, A2: Service, A3: Service, A4: Service
    {
        _buildIn = { node in
            try node.addChild(tuple.0)
            try node.addChild(tuple.1)
            try node.addChild(tuple.2)
            try node.addChild(tuple.3)
            try node.addChild(tuple.4)
        }
    }

    init<A0, A1, A2, A3, A4, A5>(_ tuple: (A0, A1, A2, A3, A4, A5))
        where A0: Service, A1: Service, A2: Service, A3: Service,
        A4: Service, A5: Service
    {
        _buildIn = { node in
            try node.addChild(tuple.0)
            try node.addChild(tuple.1)
            try node.addChild(tuple.2)
            try node.addChild(tuple.3)
            try node.addChild(tuple.4)
            try node.addChild(tuple.5)
        }
    }

    init<A0, A1, A2, A3, A4, A5, A6>(_ tuple: (A0, A1, A2, A3, A4, A5, A6))
        where A0: Service, A1: Service, A2: Service, A3: Service,
        A4: Service, A5: Service, A6: Service
    {
        _buildIn = { node in
            try node.addChild(tuple.0)
            try node.addChild(tuple.1)
            try node.addChild(tuple.2)
            try node.addChild(tuple.3)
            try node.addChild(tuple.4)
            try node.addChild(tuple.5)
            try node.addChild(tuple.6)
        }
    }

    init<A0, A1, A2, A3, A4, A5, A6, A7>(_ tuple: (A0, A1, A2, A3, A4, A5, A6, A7))
        where A0: Service, A1: Service, A2: Service, A3: Service,
        A4: Service, A5: Service, A6: Service, A7: Service
    {
        _buildIn = { node in
            try node.addChild(tuple.0)
            try node.addChild(tuple.1)
            try node.addChild(tuple.2)
            try node.addChild(tuple.3)
            try node.addChild(tuple.4)
            try node.addChild(tuple.5)
            try node.addChild(tuple.6)
            try node.addChild(tuple.7)
        }
    }

    func build(in node: Node) throws {
        try _buildIn(node)
    }
}
