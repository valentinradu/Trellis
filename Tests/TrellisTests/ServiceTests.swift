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
    private var _pool: ServicePool<Services>!
    private var _builder: ServiceBuilder<EmptyEnvironment, EmptyState>!

    override func setUp() async throws {
        _pool = .init()
        _builder = _pool.createService(id: .account)
    }

    func testSingleReducer() async {
        let expectation = XCTestExpectation()
        await _builder
            .add(reducer: .fulfill(expectation, on: AccountAction.newSession))
            .bootstrap()
        await _pool.dispatcher.send(action: AccountAction.newSession)
        wait(for: [expectation], timeout: 0.1)
    }

    func testMultipleReducers() async {
        let expectation1 = XCTestExpectation()
        let expectation2 = XCTestExpectation()
        await _builder
            .add(reducer: .fulfill(expectation1, on: AccountAction.newSession))
            .add(reducer: .fulfill(expectation2, on: NavigationAction.error))
            .bootstrap()
        await _pool.dispatcher.send(action: AccountAction.newSession)
        await _pool.dispatcher.send(action: NavigationAction.error)
        wait(for: [expectation1, expectation2], timeout: 0.1)
    }

    func testMultipleServices() async {
        let expectation1 = XCTestExpectation()
        let expectation2 = XCTestExpectation()
        await _builder
            .add(reducer: .fulfill(expectation1, on: AccountAction.newSession))
            .bootstrap()
        await _pool
            .createService(id: .navigation)
            .add(reducer: .fulfill(expectation2, on: NavigationAction.error))
            .bootstrap()

        await _pool.dispatcher.send(action: AccountAction.newSession)
        await _pool.dispatcher.send(action: NavigationAction.error)
        wait(for: [expectation1, expectation2], timeout: 0.1)
    }

    func testDestroyService() async {
        let expectation = XCTestExpectation()
        await _builder
            .add(reducer: .fulfill(expectation, on: AccountAction.newSession))
            .bootstrap()
        await _pool.destroyService(id: .account)
        await _pool.dispatcher.send(action: AccountAction.newSession)
        let result = XCTWaiter.wait(for: [expectation],
                                    timeout: 0.1)
        XCTAssertEqual(result, .timedOut)
    }

    func testErrorTransform() async {
        let expectation = XCTestExpectation()
        await _builder
            .add(reducer: .error(TestError.accessDenied, on: AccountAction.newSession))
            .add(reducer: .fulfill(expectation, on: AccountAction.error))
            .bootstrap()

        await _pool.dispatcher.send(action: AccountAction.newSession)
        wait(for: [expectation], timeout: 0.1)
        print("fail")
    }
}
