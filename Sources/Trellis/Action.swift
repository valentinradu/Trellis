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
public protocol Action {}
//
///**
// Action type erasure
// */
//public struct AnyAction: Action {
//    public let base: AnyHashable
//    private let _hash: (inout Hasher) -> Void
//
//    public init<A>(_ action: A) where A: Action {
//        base = action
//        _hash = { hasher in
//            action.hash(into: &hasher)
//        }
//    }
//
//    public init(_ action: AnyAction) {
//        base = action.base
//        _hash = { hasher in
//            action.hash(into: &hasher)
//        }
//    }
//
//    public static func == <A>(lhs: Self, rhs: A) -> Bool
//        where A: Action
//    {
//        if let rhs = rhs as? Self {
//            return lhs.base == rhs.base
//        } else if let lhs = lhs.base as? A {
//            return lhs == rhs
//        } else {
//            return false
//        }
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        _hash(&hasher)
//    }
//
//    public func `as`<A>(_: A.Type) -> A? where A: Action {
//        self as? A ?? base as? A
//    }
//}
