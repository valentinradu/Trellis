//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Firestarter
import XCTest

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
final class MiddlewareTests: XCTestCase {
    @Dispatcher private var _dispatcher
    private var _service: TestService!
    private var _middleware: TestMiddleware!

    override func setUp() {
        _service = TestService()
        _middleware = TestMiddleware()

        _dispatcher.reset(history: true,
                          reducers: true,
                          middlewares: true)
        _dispatcher.register(reducer: _service)
        _dispatcher.register(middleware: _middleware)
    }

    func testMiddlewareSuccess() async throws {
        _middleware.authState = .authenticated
        try await _dispatcher.send(TestAction.play)

        // Reducers and middleware got the action
        XCTAssertEqual(_middleware.preActions.map(\.1), [.play])
        XCTAssertEqual(_middleware.postActions.map(\.1), [.play])
        XCTAssertEqual(_service.actions.map(\.1), [.play])
        XCTAssertEqual(_middleware.failures.map(\.1), [])

        // Reducers and middleware got the action in the right order
        XCTAssertLessThan(_middleware.preActions[0].0, _service.actions[0].0)
        XCTAssertLessThan(_service.actions[0].0, _middleware.postActions[0].0)
    }

    func testMiddlewareFailure() async throws {
        _middleware.authState = .authenticated
        do {
            try await _dispatcher.send(TestAction.closeAccount)
            XCTFail()
        } catch {
            // Reducers and middleware got the action only in the right stage
            XCTAssertEqual(_middleware.preActions.map(\.1), [.closeAccount])
            XCTAssertEqual(_middleware.postActions.map(\.1), [])
            XCTAssertEqual(_service.actions.map(\.1), [])
            XCTAssertEqual(_middleware.failures.map(\.1), [.closeAccount])
            XCTAssertEqual(_middleware.failures.map { $0.2 as? TestError },
                           [TestError.accessDenied])

            // The action went from a stage to another in the right order
            XCTAssertLessThan(_middleware.preActions[0].0, _middleware.failures[0].0)
        }
    }

    func testMiddlewareNoRewrite() async throws {
        _middleware.authState = .authenticated
        try await _dispatcher.send(TestAction.logout)

        XCTAssertEqual(_service.actions.map(\.1), [.logout])
    }

    func testMiddlewareRedirect() async throws {
        _middleware.authState = .unauthenticated
        try await _dispatcher.send(TestAction.play)

        XCTAssertEqual(_service.actions.map(\.1), [.postpone(.play, until: .login)])
    }

    func testMiddlewareWaitForOthers() async throws {
        _middleware.authState = .unauthenticated
        try await _dispatcher.send(TestAction.registerNewDevice(id: ""))

        // `.registerNewDevice` should not be called until authenticated
        XCTAssertEqual(_service.actions.map(\.1.name),
                       [.postpone(.registerNewDevice, until: .login)])

        _middleware.authState = .authenticated
        try await _dispatcher.send(TestAction.login(email: "", password: ""))

        // `.registerNewDevice` should only be called if `.fetchAccount` was already called, or, if not, right after it
        XCTAssertEqual(
            _service.actions.map(\.1.name),
            [
                .postpone(.registerNewDevice, until: .login),
                .login,
                .postpone(.registerNewDevice, until: .fetchAccount)
            ]
        )

        try await _dispatcher.send(TestAction.fetchAccount)

        XCTAssertEqual(
            _service.actions.map(\.1.name),
            [
                .postpone(.registerNewDevice, until: .login),
                .login,
                .postpone(.registerNewDevice, until: .fetchAccount),
                .fetchAccount,
                .registerNewDevice
            ]
        )
        XCTAssertLessThan(_service.actions[0].0, _service.actions[1].0)
    }

    func testMiddlewareQueueActionsUntilOther() async throws {
        _middleware.authState = .unauthenticated
        try await _dispatcher.send(TestAction.fetchAccount)
        try await _dispatcher.send(TestAction.registerNewDevice(id: ""))

        _middleware.authState = .authenticated
        try await _dispatcher.send(TestAction.login(email: "", password: ""))

        XCTAssertEqual(
            _service.actions.map(\.1.name),
            [
                .postpone(.fetchAccount, until: .login),
                .postpone(.registerNewDevice, until: .login),
                .login,
                .fetchAccount,
                .registerNewDevice
            ]
        )
    }

    func testMiddlewareWaitOnlyForFutureOthers() async throws {
        _middleware.authState = .authenticated
        try await _dispatcher.send(TestAction.login(email: "", password: ""))

        try await _dispatcher.send(
            TestAction
                .fetchAccount
                .then(other: .registerNewDevice(id: ""))
        )

        XCTAssertEqual(_service.actions.map(\.1.name),
                       [.login, .fetchAccount, .registerNewDevice])
    }
}
