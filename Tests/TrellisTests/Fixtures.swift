//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Trellis
import XCTest

enum TestError: Error, Equatable {
    case accessDenied
}

actor TestEnvironment {}

enum AccountAction: Action, Equatable {
    case login(email: String)
    case newSession
    case error

    func transform(error: Error) -> TransfromErrorResult<Self> {
        .to(action: .error)
    }
}

struct AccountState {
    fileprivate(set) var email: String = ""
}

enum NavigationAction: Action, Equatable {
    case navigate(to: String)
    case error

    func transform(error: Error) -> TransfromErrorResult<Self> {
        .to(action: .error)
    }
}

struct NavigationState {
    fileprivate(set) var path: String = ""
}
