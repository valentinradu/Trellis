//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Foundation

/**
 Actions are atomic units that drive all the other actors: the dispatcher fires them and the workers execute their action-associated tasks as a result. Middleware is called before and after each action is processed and can be used to redirect an action to another or bulk-handle failures.
 Any class, struct or enum can implement the `Action` protocol as long as it has a unique name used to identify it. However, most of the time we define actions in an enum:

 ```
 enum GatekeeperAction: Action, Equatable {
     case login(email: String, password: String)
     case logout
     case resetPassword

     enum Name: Equatable {
         case login
         case logout
         case resetPassword
     }

     var name: Name {
         switch self {
         case .login: return .login
         case .logout: return .logout
         case .resetPassword: return .resetPassword
         }
     }
 }
 ```
 */
public protocol Action {
    associatedtype Name: Hashable
    
    /// The action name
    var name: Name { get }
}

/**
 Type-erasure for `Action`s
 */
public struct AnyAction: Action {
    public typealias Name = AnyHashable

    public let wrappedValue: Any
    public let name: Name
    public init<A: Action>(_ action: A) {
        if let anyAction = action as? AnyAction {
            self = anyAction
        }
        else {
            self.wrappedValue = action
            name = AnyHashable(action.name)
        }
    }
}

public extension Action {
    /// Used to chain multiple actions one after the other
    func then(other: Self) -> ActionFlow<Self> {
        ActionFlow(actions: [self, other])
    }
}

/**
 A chain of actions sent to workers one after the other
 */
public struct ActionFlow<A: Action> {
    /// All the actions in this flow in the execution order.
    let actions: [A]
    
    init(actions: [A]) {
        self.actions = actions
    }
    
    public init() {
        actions = []
    }

    /// Concatenate this chain with another, keeping the execution order.
    public func then(_ other: ActionFlow) -> ActionFlow {
        ActionFlow(actions: actions + other.actions)
    }

    /// Execute a new action after this chain of actions.
    public func then(_ action: A) -> ActionFlow {
        ActionFlow(actions: actions + [action])
    }
}
