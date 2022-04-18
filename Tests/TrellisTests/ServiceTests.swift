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
    private var _context: GenericContext!

    override func setUp() async throws {
        _context = GenericContext()
    }

    func testSingleService() async throws {
        let cluster = try await Bootstrap {
            GenericService()
                .environment(\.genericContext, value: _context)
        }

        try await cluster.send(action: GenericAction.login)

        let contextActions = await _context.actions
        XCTAssertEqual(contextActions, [.login])
    }

    func testSerialServices() async throws {
        let cluster = try await Bootstrap {
            Group {
                GenericService(name: .service1)
                GenericService(name: .service2)
            }
            .environment(\.genericContext, value: _context)
            .serial()
        }

        try await cluster.send(action: GenericAction.login)

        let contextActions = await _context.actions
        let contextServices = await _context.services
        XCTAssertEqual(contextActions, [.login, .login])
        XCTAssertEqual(contextServices, [.service1, .service2])
    }

    func testEmitter() async throws {
        let stream = AsyncStream<any Action> { continuation in
            for action in [GenericAction.login, GenericAction.error] {
                continuation.yield(action)
            }
            continuation.finish()
        }

        _ = try await Bootstrap {
            GenericService()
                .emit(using: stream, consumeAtBootstrap: true)
                .environment(\.genericContext, value: _context)
        }

        let contextActions = await _context.actions
        XCTAssertEqual(contextActions, [.login, .error])
    }

    func testErrorTransform() async throws {
        let cluster = try await Bootstrap {
            Group {
                GenericService()
                ErrorService(error: .accessDenied, on: .login)
            }
            .serial()
            .environment(\.genericContext, value: _context)
            .transformError { _ in
                GenericAction.error
            }
        }

        try await cluster.send(action: GenericAction.login)

        let actions = await _context.actions
        XCTAssertEqual(actions, [.login, .error])
    }

    func testStore() async throws {
        let cluster = try await Bootstrap {
            Store(model: GenericContext.self)
                .mutate(on: GenericAction.self) { context, action, _ in
                    await context.add(action: action)
                }
                .with(model: _context)
        }

        try await cluster.send(action: GenericAction.login)

        let actions = await _context.actions
        XCTAssertEqual(actions, [.login])
    }
    
    func testMiddleware() async throws {
        let cluster = try await Bootstrap {
            EmptyService()
                .pre(action: GenericAction.login) {
                    await self._context.add(action: .login)
                }
                .post(action: GenericAction.login) {
                    await self._context.add(action: .login)
                }
        }
        
        try await cluster.send(action: GenericAction.login)

        let actions = await _context.actions
        XCTAssertEqual(actions, [.login, .login])
    }
}
