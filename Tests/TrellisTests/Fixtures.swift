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
    private(set) var services: [ServiceName] = []
    func add(action: AccountAction) {
        actions.append(action)
    }

    func add(service: ServiceName) {
        services.append(service)
    }
}

enum AccountAction: Action, Hashable {
    case login
    case error
}

enum ServiceName {
    case service1
    case service2
}

final class AccountState: Equatable {
    static func == (lhs: AccountState, rhs: AccountState) -> Bool {
        lhs.services == rhs.services
            && lhs.actions == rhs.actions
    }

    var services: [ServiceName] = []
    var actions: [AccountAction] = []
}

private struct AccountStateKey: EnvironmentKey {
    static var defaultValue: AccountState = .init()
}

private struct AccountContextKey: EnvironmentKey {
    static var defaultValue: AccountContext = .init()
}

extension EnvironmentValues {
    var accountState: AccountState {
        get { self[AccountStateKey.self] }
        set { self[AccountStateKey.self] = newValue }
    }

    var accountContext: AccountContext {
        get { self[AccountContextKey.self] }
        set { self[AccountContextKey.self] = newValue }
    }
}

struct AccountService: Service {
    @Environment(\.accountState) private var _state
    @Environment(\.accountContext) private var _context

    var body: some Service {
        Reducer(state: _state,
                context: _context,
                reduce: Reducers.record())
    }
}

class MutableRef<I> {
    var value: I
    init(_ value: I) {
        self.value = value
    }
}

typealias AccountReducer = Reducer<AccountState, AccountContext, AccountAction>.Reduce

enum Reducers {
    static func record(delay: Bool = false, service: ServiceName = .service1) -> AccountReducer {
        { state, action in
            state.actions.append(action)
            state.services.append(service)
            return { _, env in
                if delay {
                    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                }

                await env.add(action: action)
                await env.add(service: service)
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
