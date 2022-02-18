//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Firestarter
import XCTest

class State {}
class TestDependency {}

struct TestServiceKey: DependencyKey {
    static var value: TestDependency = .init()
}

extension DependencyRepository {
    var testDependency: TestDependency {
        get { self[TestServiceKey.self] }
        set { self[TestServiceKey.self] = newValue }
    }
}

/// To make things easier to follow, the tests are working with a set of toy actions that emulate an app that has authentication, both as a regular user and admin, a simple audio player available only to authenticated users and a set of admin-specific actions.
indirect enum TestAction: Action, Hashable {
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
    case postpone(TestAction, until: TestAction.Name)

    // This section is required because Swift doesn't synthetize the **name** of the enum and we can't use the enum itself since some have associated values (e.g. `.login(email: String, password: String)`
    indirect enum Name: Hashable {
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
        case postpone(Name, until: Name)
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
        case let .postpone(action, until): return .postpone(action.name, until: until)
        }
    }
}

enum TestError: Error, Equatable {
    case accessDenied
}

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
class TestViewModel: Service {
    @Dependency(\.testDependency) var testDependency
    var actions: [(Date, TestAction)] = []

    func receive(_ action: TestAction) async throws -> ActionFlow<TestAction> {
        try await Task.sleep(nanoseconds: UInt64(0.3 * Double(NSEC_PER_SEC)))
        actions.append((Date.now, action))
        return .noop
    }
}

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
class TestMiddleware: Middleware {
    @Dependency(\.dispatcher) private var _dispatcher

    enum AuthState {
        case unauthenticated
        case authenticated
        case admin
    }

    var waitForAuthentication: ActionFlow<TestAction> = .noop
    var waitForAccountFetching: ActionFlow<TestAction> = .noop
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
        // If account is unauthenticated but the action requires authentication, look behind, if login action was already sent, send your action, if not, wait until it is and then send your action
        if authState == .unauthenticated,
           authenticatedActionsNames.contains(action.name)
        {
            let redirection: TestAction = .postpone(action,
                                                    until: .login)
            return .redirect(to: .single(action: redirection))
        }

        // If we have to register the device id, check if the account is unauthenticated, if so, look behind in history and send `.registerNewDevice` either right away, if `.login` was already sent, or right after `.login` get sent.
        // Alternatively, if the account is already authenticated, wait for `.fetchAccount` and send it right after it
        if action.name == .registerNewDevice {
            if authState == .unauthenticated {
                let redirection: TestAction = .postpone(action,
                                                        until: .login)
                return .redirect(to: .single(action: redirection))
            } else {
                if !_dispatcher.history.actions
                    .compactMap({ $0.wrappedValue as? TestAction })
                    .map(\.name)
                    .contains(TestAction.fetchAccount.name)
                {
                    let redirection: TestAction = .postpone(action,
                                                            until: .fetchAccount)
                    return .redirect(to: .single(action: redirection))
                } else {
                    return .none
                }
            }
        }

        // If the account is not authenticated but we try to send an action that require authentication, navigate the user to the login page (we'd normally also clear the  state here)
        if authState == .unauthenticated,
           authenticatedActionsNames.contains(action.name)
        {
            return .redirect(to: .single(action: .nav(path: "/login")))
        }

        if authState != .admin,
           adminActionsNames.contains(action.name)
        {
            throw TestError.accessDenied
        }

        if action.name == .login, !waitForAuthentication.actions.isEmpty {
            defer {
                waitForAuthentication = .noop
            }
            return .redirect(to: action.then(flow: waitForAuthentication))
        }

        if action.name == .fetchAccount, !waitForAccountFetching.actions.isEmpty {
            defer {
                waitForAccountFetching = .noop
            }
            return .redirect(to: action.then(flow: waitForAccountFetching))
        }

        return .none
    }

    func post(action: TestAction) {
        switch action {
        case let .postpone(other, until):
            if until == .fetchAccount {
                waitForAccountFetching = waitForAccountFetching.then(other)
            } else if until == .login {
                waitForAuthentication = waitForAuthentication.then(other)
            }
        default:
            break
        }

        postActions.append((Date.now, action))
    }

    func failure(action: TestAction, error: Error) {
        failures.append((Date.now, action, error))
    }
}
