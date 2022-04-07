//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Trellis
import XCTest

enum AccountError: Error, Equatable {
    case accessDenied
}

actor AccountContext {
    private(set) var actions: [AccountAction] = []
    func add(action: AccountAction) {
        actions.append(action)
    }
}

enum AccountAction: Action, Hashable {
    case login
    case error
}

class AccountState {
    var actions: [AccountAction] = []
}

typealias AccountReducer = Reducer<AccountState, AccountContext, AccountAction>.Reduce

enum Reducers {
    static func record(delay: Bool = false) -> AccountReducer {
        { state, action in
            state.actions.append(action)
            return { _, env in
                if delay {
                    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                }

                await env.add(action: action)
            }
        }
    }

    static func error(_ error: AccountError,
                      on searchedAction: AccountAction) -> AccountReducer
    {
        { _, action in
            { _, _ in
                if action == searchedAction {
                    throw error
                }
            }
        }
    }

    static func inert() -> AccountReducer {
        { _, _ in
            .none
        }
    }
}
