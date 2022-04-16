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

private struct AccountContextKey: EnvironmentKey {
    static var defaultValue: AccountContext = .init()
}

extension EnvironmentValues {
    var accountContext: AccountContext {
        get { self[AccountContextKey.self] }
        set { self[AccountContextKey.self] = newValue }
    }
}

struct AccountService: Service {
    @Environment(\.accountContext) private var _context
    private let _delay: Bool
    private let _name: ServiceName

    init(delay: Bool = false,
         name: ServiceName = .service1)
    {
        _delay = delay
        _name = name
    }
    
    var body: some Service {
        EmptyService()
            .on { action in
                guard let action = action as? AccountAction else {
                    return
                }

                if _delay {
                    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                }

                await _context.add(action: action)
                await _context.add(service: _name)
            }
    }
}

struct ErrorService: Service {
    private let _error: AccountError
    private let _action: AccountAction

    init(error: AccountError,
         on action: AccountAction)
    {
        _error = error
        _action = action
    }
    
    var body: some Service {
        EmptyService()
            .on { action in
                guard let action = action as? AccountAction else {
                    return
                }
                if action == _action {
                    throw _error
                }
            }
    }
}
