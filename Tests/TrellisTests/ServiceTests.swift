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
    private var _builder: ServiceBuilder<AccountEnvironment, AccountState, AnyReducers<AccountState>>!
    private var _state: AccountState!
    private var _environment: AccountEnvironment!

    override func setUp() async throws {
        _pool = .init()
        _state = AccountState()
        _environment = AccountEnvironment()
        _builder = _pool
            .build(service: .account)
            .set(initialState: _state)
            .set(environment: _environment)
    }

    func testSingleReducer() async {
        await _builder
            .add(reducer: .record())
            .bootstrap()
        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let stateActions = _state.actions
        let environmentActions = await _environment.actions
        XCTAssertEqual(stateActions, [.login])
        XCTAssertEqual(environmentActions, [.login])
    }

    func testStatelessReducer() async {
        await _pool
            .build(service: .account)
            .set(environment: _environment)
            .add(reducer: Reducer { _, action in
                SideEffect { _, environment in
                    await environment.add(action: action)
                }
            })
            .bootstrap()

        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let environmentActions = await _environment.actions
        XCTAssertEqual(environmentActions, [.login])
    }

    func testCancelDuplicates() async {
        await _builder
            .add(reducer: .record(delay: true))
            .bootstrap()

        await _pool.dispatch(action: AccountAction.login)
        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let environmentActions = await _environment.actions
        XCTAssertEqual(Set(environmentActions), Set([.login, .error]))
    }

    func testMultipleReducers() async {
        await _builder
            .add(reducer: .record())
            .add(reducer: .record())
            .bootstrap()
        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .login])
    }

    func testMultipleServices() async {
        await _builder
            .add(reducer: .record())
            .bootstrap()
        await _pool
            .build(service: .account2)
            .set(initialState: _state)
            .set(environment: _environment)
            .add(reducer: .record())
            .bootstrap()

        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .login])
    }

    func testDestroyService() async {
        await _builder
            .add(reducer: .record())
            .bootstrap()
        await _pool.remove(service: .account)
        await _pool.dispatch(action: AccountAction.login)

        let actions = _state.actions
        XCTAssertEqual(actions, [])
    }

    func testErrorTransform() async {
        await _builder
            .add(reducer: .error(.accessDenied, on: .login))
            .add(reducer: .record())
            .bootstrap()

        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .error])
    }
}
