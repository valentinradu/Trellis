//
//  File.swift
//
//
//  Created by Valentin Radu on 16/04/2022.
//

import Foundation

protocol Middleware {
    func pre(action: any Action) async throws -> Void
    func post(action: any Action) async throws -> Void
}

private struct MiddlewareService<W>: Service, Middleware
    where W: Service
{
    private let _pre: ActionObserver?
    private let _post: ActionObserver?
    private let _wrappedService: W

    init(pre: ActionObserver? = nil,
         post: ActionObserver? = nil,
         @ServiceBuilder builder: () -> W)
    {
        _pre = pre
        _post = post
        _wrappedService = builder()
    }

    var body: some Service {
        _wrappedService
    }

    func pre(action: any Action) async throws {
        try await _pre?(action)
    }

    func post(action: any Action) async throws {
        try await _post?(action)
    }
}

public typealias ActionObserver = (any Action) async throws -> Void
public typealias SingleActionObserver = () async throws -> Void

public extension Service {
    func pre<A>(action: A.Type,
                closure: @escaping (A) async throws -> Void) -> some Service
        where A: Action
    {
        MiddlewareService(pre: { action in
            if let action = action as? A {
                try await closure(action)
            }
        }) {
            self
        }
    }

    func pre(_ closure: @escaping ActionObserver) -> some Service {
        MiddlewareService(pre: closure) {
            self
        }
    }

    func pre<A>(action: A,
                closure: @escaping SingleActionObserver) -> some Service
        where A: Action & Equatable
    {
        let singleActionClosure: ActionObserver = {
            if let innerAction = $0 as? A, innerAction == action {
                try await closure()
            }
        }

        return MiddlewareService(pre: singleActionClosure) {
            self
        }
    }
    
    func post<A>(action: A.Type,
                 closure: @escaping (A) async throws -> Void) -> some Service
        where A: Action
    {
        MiddlewareService(post: { action in
            if let action = action as? A {
                try await closure(action)
            }
        }) {
            self
        }
    }

    func post(_ closure: @escaping ActionObserver) -> some Service {
        MiddlewareService(post: closure) {
            self
        }
    }

    func post<A>(action: A,
                 closure: @escaping SingleActionObserver) -> some Service
        where A: Action & Equatable
    {
        let singleActionClosure: ActionObserver = {
            if let innerAction = $0 as? A, innerAction == action {
                try await closure()
            }
        }

        return MiddlewareService(post: singleActionClosure) {
            self
        }
    }
}
