//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Trellis
import XCTest

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
final class DispatcherTests: XCTestCase {
    private var _dispatcher: Dispatcher!
    private var _service: Service<TestEnvironment, AccountState>!
    private var _store: Store<AccountState>!

    override func setUp() async throws {
        _dispatcher = Dispatcher()
        let (store, service) = await AccountService.bootstrap()
        _service = service
        _store = store
    }

    func testRegisterService() async {
        let expectation = XCTestExpectation(description: "Service is called")
        let reducer = AccountService.fulfillReducer(expectation: expectation)
        await _service.add(reducer: reducer)

        await _dispatcher.register(service: _service)
        await _dispatcher.send(action: AccountAction.login(email: "a"))

        let result = XCTWaiter.wait(for: [expectation], timeout: 0.1)
        XCTAssertEqual(result, .completed)
    }

    func testUnegisterService() async {
        let expectation = XCTestExpectation(description: "Service is called")
        let reducer = AccountService.fulfillReducer(expectation: expectation)
        await _service.add(reducer: reducer)

        await _dispatcher.register(service: _service)
        await _dispatcher.unregister(service: _service)
        await _dispatcher.send(action: AccountAction.login(email: "a"))

        let result = XCTWaiter.wait(for: [expectation], timeout: 0.25)
        XCTAssertEqual(result, .timedOut)
    }
}
