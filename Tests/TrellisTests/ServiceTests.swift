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
    private var _state: AccountState!
    private var _environment: AccountContext!

    override func setUp() async throws {
        _state = AccountState()
        _environment = AccountContext()
    }

    func testSingleService() async throws {
        let cluster = Cluster {
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
        }

        try await cluster.receive(action: AccountAction.login)

        let stateActions = _state.actions
        let environmentActions = await _environment.actions
        XCTAssertEqual(stateActions, [.login])
        XCTAssertEqual(environmentActions, [.login])
    }

    func testStatelessReducer() async throws {
        let cluster = Cluster {
            Reducer(context: _environment,
                    reduce: { _, action in
                        { _, environment in
                            await environment.add(action: action)
                        }
                    })
        }

        try await cluster.receive(action: AccountAction.login)

        let environmentActions = await _environment.actions
        XCTAssertEqual(environmentActions, [.login])
    }

    func testMultipleService() async throws {
        let cluster = Cluster {
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
        }

        try await cluster.receive(action: AccountAction.login)

        let stateActions = _state.actions
        let environmentActions = await _environment.actions
        XCTAssertEqual(stateActions, [.login, .login])
        XCTAssertEqual(environmentActions, [.login, .login])
    }

    func testErrorTransform() async throws {
        let cluster = Cluster {
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.error(.accessDenied, on: .login))
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
        }
        .transformError { _ in
            AccountAction.error
        }

        try await cluster.receive(action: AccountAction.login)

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .error])
    }

    func testDirectAccess() async throws {
        let store = Store<[AccountAction]>(initialState: [])
        let dispatch = { (action: any Action) async throws in }
        let reducer = Reducers.record()
        let environment = AccountContext()
        var state = AccountState()
        if let sideEffect = reducer(&state, .login) {
            try await sideEffect(dispatch, environment)
        }

        let dispatchActions = store.state
        let reducerActions = state.actions
        let environmentActions = await environment.actions

        XCTAssertEqual(dispatchActions, [])
        XCTAssertEqual(reducerActions, environmentActions)
    }
}
