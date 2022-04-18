//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Trellis
import XCTest

enum GenericError: Error, Equatable {
    case accessDenied
}

actor GenericContext {
    private(set) var actions: [GenericAction] = []
    private(set) var services: [ServiceName] = []
    func add(action: GenericAction) {
        actions.append(action)
    }

    func add(service: ServiceName) {
        services.append(service)
    }
}

enum GenericAction: Action, Hashable {
    case login
    case error
}

enum ServiceName {
    case service1
    case service2
}

private struct GenericContextKey: EnvironmentKey {
    static var defaultValue: GenericContext = .init()
}

extension EnvironmentValues {
    var genericContext: GenericContext {
        get { self[GenericContextKey.self] }
        set { self[GenericContextKey.self] = newValue }
    }
}

struct GenericService: Service {
    @Environment(\.genericContext) private var _context
    private let _delay: Bool
    private let _name: ServiceName

    init(delay: Bool = false,
         name: ServiceName = .service1)
    {
        _delay = delay
        _name = name
    }

    func receive(action: any Action) async throws {
        guard let action = action as? GenericAction else {
            return
        }

        if _delay {
            try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        }

        await _context.add(action: action)
        await _context.add(service: _name)
    }
}

struct ErrorService: Service {
    private let _error: GenericError
    private let _action: GenericAction

    init(error: GenericError,
         on action: GenericAction)
    {
        _error = error
        _action = action
    }

    var body: some Service {
        EmptyService()
    }

    func receive(action: any Action) async throws {
        guard let action = action as? GenericAction else {
            return
        }

        if action == _action {
            throw _error
        }
    }
}
