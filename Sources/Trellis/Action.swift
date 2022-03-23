//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Foundation

/**
 Reducers react to **actions** and mutate the state in a predictable way.
 ```
 enum GatekeeperAction: Action {
     case login(email: String, password: String)
     case logout
     case resetPassword
 }
 ```
 */
public protocol Action {
    /**
     When an action's side effects fail, this method is called to transform
     the resulting error into another action (e.g. `.error(Error)`).
     */
    func transform(error: Error) -> TransfromErrorResult<Self>
}

/**
 The result of `transform(error:)` function.
 */
public enum TransfromErrorResult<A> where A: Action {
    /// No action will be dispatched after the failure.
    case none
    /// `action` will be dispatched after the failure.
    case to(action: A)
}
