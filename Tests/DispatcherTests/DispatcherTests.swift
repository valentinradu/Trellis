//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Dispatcher
import XCTest

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class DispatcherTests: XCTestCase {
    private var _dispatcher: Dispatcher!
    private var _service: TestService!
    private var _middleware: TestMiddleware!

    override func setUp() {
        _dispatcher = Dispatcher()
        _service = TestService()
        _middleware = TestMiddleware()

        _dispatcher.register(worker: _service)
        _dispatcher.register(middleware: _middleware)
    }

    func testRegister() async throws {
        let otherService = TestService()
        _dispatcher.register(worker: otherService)
        try await _dispatcher.fire(TestAction.resetPassword)

        XCTAssertEqual(otherService.actions.map(\.1), [.resetPassword])
    }

    func testPurgeQueue() async throws {
        _middleware.authState = .unauthenticated
        try await _dispatcher.fire(TestAction.registerNewDevice(id: ""))
        _middleware.authState = .authenticated
        _dispatcher.purge(from: .shelf)
        try await _dispatcher.fire(
            TestAction
                .login(email: "", password: "")
                .then(other: .fetchAccount)
        )

        // Since we purged the queue `.registerNewDevice` should not fire anymore, even if the triggering action (`.fetchAccount`) did
        XCTAssertEqual(_service.actions.map(\.1.name),
                       [.login, .fetchAccount])
    }

    func testPurgeLedger() async throws {
        _middleware.authState = .authenticated
        try await _dispatcher.fire(
            TestAction
                .login(email: "", password: "")
                .then(other: .fetchAccount)
        )

        _dispatcher.purge(from: .ledger)
        try await _dispatcher.fire(TestAction.registerNewDevice(id: ""))

        // Even if all dependencies should be solved, `.registerNewDevice` won't fire since we purged the ledger and would require an additional `.fetchAccount` to do so
        XCTAssertEqual(_service.actions.map(\.1.name),
                       [.login, .fetchAccount])
    }

    func testFireSuccess() async throws {
        try await _dispatcher.fire(TestAction.resetPassword)
        XCTAssertEqual(_service.actions.map(\.1), [.resetPassword])
    }

    func testFireError() async throws {
        do {
            try await _dispatcher.fire(TestAction.closeAccount)
            XCTFail()
        } catch {
            XCTAssertEqual(error as? TestError, TestError.accessDenied)
        }
    }
}
