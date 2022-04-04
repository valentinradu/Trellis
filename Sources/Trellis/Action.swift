//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

/**
 Reducers react to **actions** and mutate the state in a predictable way.
 ```
 enum AccountAction: Action {
     case login(email: String, password: String)
     case logout
     case resetPassword
 }
 ```
 */
public protocol Action: Hashable {}

/**
 Action type erasure
 */
public struct AnyAction: Action {
    public let base: Any
    private let _hash: (inout Hasher) -> Void

    public init<A>(_ action: A) where A: Action {
        base = action
        _hash = { hasher in
            action.hash(into: &hasher)
        }
    }

    public init(_ action: AnyAction) {
        base = action.base
        _hash = { hasher in
            action.hash(into: &hasher)
        }
    }

    public static func == <A>(lhs: Self, rhs: A) -> Bool
        where A: Action
    {
        if let lhs = lhs as? A ?? lhs.base as? A {
            return lhs == rhs
        } else {
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        _hash(&hasher)
    }
}
