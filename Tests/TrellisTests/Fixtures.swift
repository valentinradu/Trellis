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

enum Services: Hashable {
    case account
    case navigation
}

extension Reducer {
    static func fulfill<E, S, A>(_ expectation: XCTestExpectation,
                                 on searchedAction: A) -> Reducer<E, S, A>
        where A: Action & Equatable, E: Actor
    {
        Reducer<E, S, A>({ _, action in
            .operation { _, _ in
                if action == searchedAction {
                    print("fulfill")
                    expectation.fulfill()
                }
            }
        })
    }

    static func error<E, S, A>(_ error: Error,
                               on searchedAction: A) -> Reducer<E, S, A>
        where A: Action & Equatable, E: Actor
    {
        Reducer<E, S, A>({ _, action in
            .operation { _, _ in
                if action == searchedAction {
                    print("error")
                    throw error
                }
            }
        })
    }
}
