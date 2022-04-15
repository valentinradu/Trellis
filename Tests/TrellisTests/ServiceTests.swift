//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Trellis
import XCTest

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
final class ServiceTests: XCTestCase {
    private var _context: AccountContext!

    override func setUp() async throws {
        _context = AccountContext()
    }

    func testSingleService() async throws {
        let cluster = try await Bootstrap {
            AccountService()
                .environment(\.accountContext, value: _context)
        }

        try await cluster.send(action: AccountAction.login)

        let contextActions = await _context.actions
        XCTAssertEqual(contextActions, [.login])
    }

    func testSerialServices() async throws {
        let cluster = try await Bootstrap {
            Group {
                AccountService(name: .service1)
                AccountService(name: .service2)
            }
            .environment(\.accountContext, value: _context)
            .serial()
        }

        try await cluster.send(action: AccountAction.login)

        let contextActions = await _context.actions
        let contextServices = await _context.services
        XCTAssertEqual(contextActions, [.login, .login])
        XCTAssertEqual(contextServices, [.service1, .service2])
    }

    func testEmitter() async throws {
        let stream = AsyncStream<any Action> { continuation in
            for action in [AccountAction.login, AccountAction.error] {
                continuation.yield(action)
            }
            continuation.finish()
        }

        _ = try await Bootstrap {
            Emitter(stream: stream) {
                AccountService()
            }
            .consume()
            .environment(\.accountContext, value: _context)
        }

        let contextActions = await _context.actions
        XCTAssertEqual(contextActions, [.login, .error])
    }

    func testErrorTransform() async throws {
        let cluster = try await Bootstrap {
            Group {
                AccountService()
                ErrorService(error: .accessDenied, on: .login)
            }
            .environment(\.accountContext, value: _context)
            .transformError { _ in
                AccountAction.error
            }
        }

        try await cluster.send(action: AccountAction.login)

        let actions = await _context.actions
        XCTAssertEqual(actions, [.login, .error])
    }
}
