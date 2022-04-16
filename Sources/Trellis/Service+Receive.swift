//
//  File.swift
//
//
//  Created by Valentin Radu on 16/04/2022.
//

import Foundation

private struct ReceiveService<W>: Service
    where W: Service
{
    private let _closure: ActionObserver
    private let _wrappedService: W

    init(_ closure: @escaping ActionObserver,
         @ServiceBuilder builder: () -> W)
    {
        _closure = closure
        _wrappedService = builder()
    }

    var body: some Service {
        _wrappedService
    }

    func send<ID>(action: any Action, from parentId: ID) async throws
        where ID: Identity
    {
        try await _closure(action)

        let id = identity(from: parentId)

        if Body.self != Never.self {
            try await body.send(action: action,
                                from: id)
        }
    }
}

public typealias ActionObserver = (any Action) async throws -> Void

public extension Service {
    func on(_ closure: @escaping ActionObserver) -> some Service {
        ReceiveService(closure) {
            self
        }
    }
}
