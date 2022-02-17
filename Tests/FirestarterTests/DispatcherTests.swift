//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Firestarter
import XCTest

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
final class DispatcherTests: XCTestCase {
    private var _dispatcher: Dispatcher!
    private var _service: TestService!
    private var _middleware: TestMiddleware!

    override func setUp() {
        _dispatcher = Dispatcher()
        _service = TestService()
        _middleware = TestMiddleware(dispatcher: _dispatcher)

        _dispatcher.register(worker: _service)
        _dispatcher.register(middleware: _middleware)
    }

    func testRegister() async throws {
        let otherService = TestService()
        _dispatcher.register(worker: otherService)
        try await _dispatcher.publish(TestAction.resetPassword)

        XCTAssertEqual(otherService.actions.map(\.1), [.resetPassword])
    }

    func testPurgeHistory() async throws {
        _middleware.authState = .authenticated
        try await _dispatcher.publish(
            TestAction
                .login(email: "", password: "")
                .then(other: .fetchAccount)
        )

        _dispatcher.reset(history: true)
        try await _dispatcher.publish(TestAction.registerNewDevice(id: ""))

        // Even if all dependencies should be solved, `.registerNewDevice` won't publish since we purged the history and would require an additional `.fetchAccount` to do so
        XCTAssertEqual(
            _service.actions.map(\.1.name),
            [
                .login,
                .fetchAccount,
                .postpone(.registerNewDevice, until: .fetchAccount)
            ]
        )
    }

    func testPublishSuccess() async throws {
        try await _dispatcher.publish(TestAction.resetPassword)
        XCTAssertEqual(_service.actions.map(\.1), [.resetPassword])
    }

    func testPublishError() async throws {
        do {
            try await _dispatcher.publish(TestAction.closeAccount)
            XCTFail()
        } catch {
            XCTAssertEqual(error as? TestError, TestError.accessDenied)
        }
    }
}
