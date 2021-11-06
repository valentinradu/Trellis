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
    private var dispatcher: Dispatcher!
    private var service: TestService!
    private var middleware: TestMiddleware!

    override func setUp() {
        dispatcher = Dispatcher()
        service = TestService()
        middleware = TestMiddleware()

        dispatcher.register(worker: service)
        dispatcher.register(middleware: middleware)
    }

    func testRegister() async throws {
        let otherService = TestService()
        dispatcher.register(worker: otherService)
        try await dispatcher.fire(TestAction.resetPassword)

        XCTAssertEqual(otherService.actions.map(\.1), [.resetPassword])
    }

    func testPurgeQueue() async throws {
        middleware.authState = .unauthenticated
        try await dispatcher.fire(TestAction.registerNewDevice(id: ""))
        middleware.authState = .authenticated
        dispatcher.purge(from: .queue)
        try await dispatcher.fire(
            TestAction
                .login(email: "", password: "")
                .then(other: .fetchAccount)
        )

        // Since we purged the queue `.registerNewDevice` should not fire anymore, even if the triggering action (`.fetchAccount`) did
        XCTAssertEqual(service.actions.map(\.1.name),
                       [.login, .fetchAccount])
    }

    func testPurgeHistory() async throws {
        middleware.authState = .authenticated
        try await dispatcher.fire(
            TestAction
                .login(email: "", password: "")
                .then(other: .fetchAccount)
        )

        dispatcher.purge(from: .history)
        try await dispatcher.fire(TestAction.registerNewDevice(id: ""))

        // Even if all dependencies should be solved, `.registerNewDevice` won't fire since we purged the history and would require an additional `.fetchAccount` to do so
        XCTAssertEqual(service.actions.map(\.1.name),
                       [.login, .fetchAccount])
    }

    func testFireSuccess() async throws {
        try await dispatcher.fire(TestAction.resetPassword)
        XCTAssertEqual(service.actions.map(\.1), [.resetPassword])
    }

    func testFireError() async throws {
        do {
            try await dispatcher.fire(TestAction.closeAccount)
            XCTFail()
        } catch {
            XCTAssertEqual(error as? TestError, TestError.accessDenied)
        }
    }
}
