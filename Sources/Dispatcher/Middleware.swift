//
//  File.swift
//
//
//  Created by Valentin Radu on 06/11/2021.
//

import Combine

/**
 The middleware is used for:
 1) Blocking, postponing or redirecting an action *before* sending it to the workers
 2) Hadling all errors in one place, no matter their kind, as long as they originate from an worker
 3) Take additional actions, like, logging or asserting, after all the workers finished processing an action
 - remark: When using multiple middlewares, only the first one `.redirect`ing an action is considered. The rest are never called. Since middleware execution order is not guaranteed, it's best if you only redirect or defer one kind of action per middleware.
 */
public protocol Middleware {
    associatedtype A: Action
    /**
     Called before sending the action to all workers. It can be used to terminate the action, redirect it to other action or postpone it.
     */
    func pre(action: A) throws -> Rewrite<A>
    /**
     Called after all the workers finished processing the action.
     */
    func post(action: A)
    /**
     Called when a worker failed to process the action.
     */
    func failure(action: A, error: Error)
}

/**
 Middleware type erasure
 */
public struct AnyMiddleware: Middleware {
    public typealias A = AnyAction
    private let preClosure: (AnyAction) throws -> Rewrite<AnyAction>
    private let postClosure: (AnyAction) -> Void
    private let failureClosure: (AnyAction, Error) -> Void

    public init<M: Middleware>(_ source: M) {
        preClosure = {
            if let action = $0.wrappedValue as? M.A {
                let rewrite = try source.pre(action: action)
                switch rewrite {
                case let .redirect(to):
                    let newFlow = ActionFlow(actions: to.actions.map { AnyAction($0) })
                    return .redirect(to: newFlow)
                case .none:
                    return .none
                }
            }
            return Rewrite<AnyAction>.none
        }

        postClosure = {
            if let action = $0.wrappedValue as? M.A {
                source.post(action: action)
            }
        }

        failureClosure = {
            if let action = $0.wrappedValue as? M.A {
                source.failure(action: action, error: $1)
            }
        }
    }

    public func pre(action: A) throws -> Rewrite<A> {
        return try preClosure(action)
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

/**
 Action rewrite
 - seealso: Action
 */
public enum Rewrite<A: Action> {
    /// No action taken, the default behaviour of any middleware
    case none
    /// Replace the current action with another action before it reaches any worker
    case redirect(to: ActionFlow<A>)
}
