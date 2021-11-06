//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Combine

public protocol Middleware {
    associatedtype A: Action
    func pre(action: A) throws -> Rewrite<A>
    func post(action: A)
    func failure(action: A, error: Error)
}

public struct AnyMiddleware: Middleware {
    public typealias A = AnyAction
    private let preClosure: (AnyAction) throws -> Any
    private let postClosure: (AnyAction) -> Void
    private let failureClosure: (AnyAction, Error) -> Void

    public init<M: Middleware>(_ source: M) {
        preClosure = {
            if let action = $0 as? M.A {
                return try source.pre(action: action)
            }
            return Rewrite<M.A>.none
        }

        postClosure = {
            if let action = $0 as? M.A {
                source.post(action: action)
            }
        }

        failureClosure = {
            if let action = $0 as? M.A {
                source.failure(action: action, error: $1)
            }
        }
    }

    public func pre(action: A) throws -> Rewrite<A> {
        try preClosure(action) as? Rewrite<A> ?? .none
    }

    public func post(action: A) {
        postClosure(action)
    }

    public func failure(action: A, error: Error) {
        failureClosure(action, error)
    }
}

public extension Middleware {
    func pre(action _: A) -> Rewrite<A> {
        .none
    }

    func post(action _: A) {}
    func failure(action _: A, error _: Error) {}
}

public enum Rewrite<A: Action> {
    public struct DeferOptions {
        let lookBehind: Bool
        let enqueueSimilarEvents: Bool

        public init(lookBehind: Bool = false,
                    enqueueSimilarEvents: Bool = false)
        {
            self.lookBehind = lookBehind
            self.enqueueSimilarEvents = enqueueSimilarEvents
        }
    }

    case none
    case redirect(to: A)
    case `defer`(until: A.Name, options: DeferOptions = .init())
}
