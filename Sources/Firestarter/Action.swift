//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Foundation

/**
 Actions are atomic units that drive all the other actors: the dispatcher sends them while the services receive action-associated tasks as a result. Middleware is called before and after each action is processed and can be used to redirect the action or for handling all failures in one place.
 Any class, struct or enum can implement the `Action` protocol. However, most of the time we define actions in an enum:
 ```
 enum GatekeeperAction: Action, Equatable {
     case login(email: String, password: String)
     case logout
     case resetPassword
 }
 ```
 */
public protocol Action {}

/**
 Type-erasure for `Action`s
 */
public struct AnyAction: Action {
    public let wrappedValue: Any
    public init<A: Action>(_ action: A) {
        if let anyAction = action as? AnyAction {
            self = anyAction
        }
        else {
            wrappedValue = action
        }
    }
}

public extension Action {
    /// Used to chain multiple actions one after the other
    func then(other: Self) -> ActionFlow<Self> {
        ActionFlow(actions: [self, other])
    }

    func then(flow: ActionFlow<Self>) -> ActionFlow<Self> {
        ActionFlow(actions: [self] + flow.actions)
    }
}

/**
 A chain of actions sent to services one after the other
 */
public struct ActionFlow<A: Action> {
    public static func single(action: A) -> ActionFlow<A> {
        ActionFlow<A>(actions: [action])
    }

    public static var noop: ActionFlow<A> {
        ActionFlow<A>(actions: [])
    }

    /// All the actions in this flow in the execution order.
    public var actions: [A] = []

    init(actions: [A]) {
        self.actions = actions
    }

    /// Concatenate this chain with another.
    public func then(_ other: ActionFlow) -> ActionFlow {
        ActionFlow(actions: actions + other.actions)
    }

    /// Append a new action after this chain of actions.
    public func then(_ action: A) -> ActionFlow {
        ActionFlow(actions: actions + [action])
    }
}
