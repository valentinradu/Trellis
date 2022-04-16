//
//  File.swift
//
//
//  Created by Valentin Radu on 16/04/2022.
//

import Foundation

public typealias BootstrapHandler = () async throws -> Void

private struct BootstrapService<W>: Service
    where W: Service
{
    private let _closure: BootstrapHandler
    private let _wrappedService: W

    init(_ closure: @escaping BootstrapHandler,
         @ServiceBuilder builder: () -> W)
    {
        _closure = closure
        _wrappedService = builder()
    }

    var body: some Service {
        _wrappedService
    }

    func inject<ID>(environment: EnvironmentValues,
                    from parentId: ID) async throws
        where ID: Identity
    {
        let id = identity(from: parentId)

        if Body.self != Never.self {
            try await body.inject(environment: environment,
                                  from: id)
        }

        try await _closure()
    }
}

public extension Service {
    func bootstrap(_ closure: @escaping BootstrapHandler) -> some Service {
        BootstrapService(closure) {
            self
        }
    }
}
