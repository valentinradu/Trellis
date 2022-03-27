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

actor AccountEnvironment {
    private(set) var actions: [AccountAction] = []
    func add(action: AccountAction) {
        actions.append(action)
    }
}

enum AccountAction: Action, Equatable {
    case login
    case error

    func transform(error: Error) -> TransfromErrorResult<Self> {
        .to(action: .error)
    }
}

class AccountState: ObservableObject {
    @Published var actions: [AccountAction] = []
}

enum Services: Hashable {
    case account
    case account2
}

typealias AccountReducer = Reducer<AccountEnvironment, AccountState, AccountAction>

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
