//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Trellis
import XCTest

enum AccountAction: Action {
    case login(email: String)
    case newSession(email: String)
    case error(Error)

    func transform(error: Error) -> TransfromErrorResult<Self> {
        .to(action: .error(error))
    }
}

enum TestError: Error, Equatable {
    case accessDenied
}

actor TestEnvironment {}

struct AccountState {
    fileprivate(set) var email: String = ""
}

enum AccountService {
    typealias AccountReducer = (inout AccountState, AccountAction) -> SideEffect<TestEnvironment>
    static func bootstrap() async -> (Store<AccountState>, Service<TestEnvironment, AccountState>) {
        let store = Store(AccountState())
        let service = Service(environment: TestEnvironment(),
                              store: store)
        await service.add(reducer: AccountService.reducer)
        return (store, service)
    }

    static func reducer(state: inout AccountState,
                        action: AccountAction) -> SideEffect<TestEnvironment>
    {
        switch action {
        case let .login(email):
            state.email = email
            return SideEffect { dispatcher, _ in
                await dispatcher.send(action: AccountAction.newSession(email: email))
            }
        case .error:
            return .noop
        case let .newSession(email):
            print(email)
            return .noop
        }
    }

    static func fulfillReducer(expectation: XCTestExpectation) -> AccountReducer {
        { _, _ in
            expectation.fulfill()
            return .noop
        }
    }
}
