//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Dispatcher
import XCTest

class State {}

/// To make things easier to follow, the tests are working with a set of toy actions that emulate an app that has authentication, both as a regular user and admin, a simple audio player available only to authenticated users and a set of admin-specific actions.
enum TestAction: Action, Equatable {
    // Authentication
    case login(email: String, password: String)
    case logout
    case resetPassword

    // Account management
    case fetchAccount
    case patchEmail(value: String)
    case registerNewDevice(id: String)

    // Player
    case load(url: URL)
    case play
    case stop
    case skip(duration: Double)

    // Admin
    case closeAccount

    // UI
    case alert(title: String, description: String)
    case nav(path: String)
    
    // Utils
    case null

    // This section is required because Swift doesn't synthetize the **name** of the enum and we can't use the enum itself since some have associated values (e.g. `.login(email: String, password: String)`
    enum Name: Equatable {
        case login
        case logout
        case resetPassword
        case fetchAccount
        case patchEmail
        case registerNewDevice
        case load
        case play
        case stop
        case skip
        case closeAccount
        case alert
        case nav
        case null
    }

    var name: Name {
        switch self {
        case .login: return .login
        case .logout: return .logout
        case .resetPassword: return .resetPassword
        case .fetchAccount: return .fetchAccount
        case .patchEmail: return .patchEmail
        case .registerNewDevice: return .registerNewDevice
        case .load: return .load
        case .play: return .play
        case .stop: return .stop
        case .skip: return .skip
        case .closeAccount: return .closeAccount
        case .alert: return .alert
        case .nav: return .nav
        case .null: return .null
        }
    }
}

enum TestError: Error, Equatable {
    case accessDenied
}

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
class TestService: Worker {
    var actions: [(Date, TestAction)] = []

    func execute(_ action: TestAction) async throws {
        await Task.sleep(UInt64(0.3 * Double(NSEC_PER_SEC)))
        actions.append((Date.now, action))
    }
}

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
class TestMiddleware: Middleware {
    unowned let dispatcher: Dispatcher

    init(dispatcher: Dispatcher) {
        self.dispatcher = dispatcher
    }

    enum AuthState {
        case unauthenticated
        case authenticated
        case admin
    }

    var waitForAuthentication: ActionFlow<TestAction> = .init()
    var waitForAccountFetching: ActionFlow<TestAction> = .init()
    var authState: AuthState = .unauthenticated
    var preActions: [(Date, TestAction)] = []
    var postActions: [(Date, TestAction)] = []
    var failures: [(Date, TestAction, Error)] = []
    var accountActionsNames: Set<TestAction.Name> {
        [.fetchAccount, .patchEmail, .registerNewDevice]
    }

    var playerActionsNames: Set<TestAction.Name> {
        [.load, .play, .stop, .skip]
    }

    var authenticatedActionsNames: Set<TestAction.Name> {
        accountActionsNames.union(playerActionsNames)
    }

    var adminActionsNames: Set<TestAction.Name> {
        [.closeAccount]
    }

    func pre(action: TestAction) throws -> Rewrite<TestAction> {
        preActions.append((Date.now, action))
        // If account is unauthenticated but the action requires authentication, look behind, if login action was already fired, fire your action, if not, wait until it is and then fire your action
        if authState == .unauthenticated,
           authenticatedActionsNames.contains(action.name)
        {
            waitForAuthentication = waitForAuthentication.then(action)
            return .redirect(to: .null)
        }

        // If we have to register the device id, check if the account is unauthenticated, if so, look behind in history and fire `.registerNewDevice` either right away, if `.login` was already fired, or right after `.login` fires.
        // Alternatively, if the account is already authenticated, wait for `.fetchAccount` and fire right after it
        if action.name == .registerNewDevice {
            if authState == .unauthenticated {
                waitForAuthentication = waitForAuthentication.then(action)
                return .redirect(to: .null)
            } else {
                if !dispatcher.history.actions
                    .map(\.name)
                    .contains(TestAction.fetchAccount.name)
                {
                    waitForAccountFetching = waitForAccountFetching.then(action)
                    return .redirect(to: .null)
                } else {
                    return .none
                }
            }
        }

        // If the account is not authenticated but we try to fire an action that require authentication, navigate the user to the login page (we'd normally also clear the  state here)
        if authState == .unauthenticated,
           authenticatedActionsNames.contains(action.name)
        {
            return .redirect(to: .nav(path: "/login"))
        }

        if authState != .admin, adminActionsNames.contains(action.name) {
            throw TestError.accessDenied
        }

        return .none
    }

    func post(action: TestAction) {
        postActions.append((Date.now, action))
    }

    func failure(action: TestAction, error: Error) {
        failures.append((Date.now, action, error))
    }
}
