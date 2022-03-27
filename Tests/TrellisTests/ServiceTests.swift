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
            .add(reducer: Reducers.record())
            .bootstrap()
        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let stateActions = _state.actions
        let environmentActions = await _environment.actions
        let hasTasks = await _pool.hasTasks
        XCTAssertTrue(!hasTasks)
        XCTAssertEqual(stateActions, [.login])
        XCTAssertEqual(environmentActions, [.login])
    }

    func testStatelessReducer() async {
        await _pool
            .build(service: .account)
            .set(environment: _environment)
            .add(reducer: { _, action in
                { _, environment in
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
            .add(reducer: Reducers.record(delay: true))
            .bootstrap()

        await _pool.dispatch(action: AccountAction.login)
        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let environmentActions = await _environment.actions
        XCTAssertEqual(Set(environmentActions), Set([.login, .error]))
    }

    func testMultipleReducers() async {
        await _builder
            .add(reducer: Reducers.record())
            .add(reducer: Reducers.record())
            .bootstrap()
        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .login])
    }

    func testMultipleServices() async {
        await _builder
            .add(reducer: Reducers.record())
            .bootstrap()
        await _pool
            .build(service: .account2)
            .set(initialState: _state)
            .set(environment: _environment)
            .add(reducer: Reducers.record())
            .bootstrap()

        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .login])
    }

    func testDestroyService() async {
        await _builder
            .add(reducer: Reducers.record())
            .bootstrap()
        await _pool.remove(service: .account)
        await _pool.dispatch(action: AccountAction.login)

        let actions = _state.actions
        XCTAssertEqual(actions, [])
    }

    func testErrorTransform() async {
        await _builder
            .add(reducer: Reducers.error(.accessDenied, on: .login))
            .add(reducer: Reducers.record())
            .bootstrap()

        await _pool.dispatch(action: AccountAction.login)
        await _pool.waitForAllTasks()

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .error])
    }
    
    func testDirectAccess() async throws {
        let dispatch = RecordDispatch()
        let reducer = Reducers.record()
        let environment = AccountEnvironment()
        var state = AccountState()
        if let sideEffect = reducer(&state, AccountAction.login) {
            try await sideEffect(dispatch, environment)
        }
        
        let dispatchActions = await dispatch.actions
        let reducerActions = state.actions
        let environmentActions = await environment.actions
        
        XCTAssertEqual(dispatchActions, [])
        XCTAssertEqual(reducerActions, environmentActions)
    }
}
