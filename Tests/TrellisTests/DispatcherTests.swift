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
//    private var _dispatcher: Dispatcher!
//    private var _service: Service<TestEnvironment, AccountState>!
//    private var _store: Store<AccountState>!
//    private var _environment: TestEnvironment!
//
//    override func setUp() async throws {
//        _dispatcher = Dispatcher()
//        let (environment, store, service) = await AccountServiceBuilder.bootstrap()
//        _service = service
//        _store = store
//        _environment = environment
//    }
//
//    func testRegisterService() async {
//        let action: AccountAction = .newSession
//        let reducer = AccountServiceBuilder.fulfillReducer(action: action)
//        await _service.add(reducer: reducer)
//
//        await _dispatcher.register(service: _service)
//        await _dispatcher.send(action: action)
//
//        let result = await _environment.wait()
//        XCTAssertEqual(result, .completed)
//    }
//
//    func testUnegisterService() async {
//        let action = AccountAction.newSession
//        let reducer = AccountServiceBuilder.fulfillReducer(action: action)
//        await _service.add(reducer: reducer)
//
//        await _dispatcher.register(service: _service)
//        await _dispatcher.unregister(service: _service)
//        await _dispatcher.send(action: action)
//
//        let result = await _environment.wait()
//        XCTAssertEqual(result, .timedOut)
//    }
//
//    func testErrorTransform() async {
//        await _service
//            .add(reducer: AccountServiceBuilder.errorReducer(error: TestError.accessDenied))
//        await _service
//            .add(reducer: AccountServiceBuilder.fulfillReducer(action: AccountAction.error))
//
//        await _dispatcher.register(service: _service)
//        await _dispatcher.send(action: AccountAction.newSession)
//
//        let result = await _environment.wait()
//        XCTAssertEqual(result, .completed)
//    }
//
//    func testMultipleActions() async {}
}
