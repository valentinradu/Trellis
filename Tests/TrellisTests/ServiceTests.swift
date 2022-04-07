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
        let cluster = try Bootstrap {
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
        }

        try await cluster.send(action: AccountAction.login)

        let stateActions = _state.actions
        let environmentActions = await _environment.actions
        XCTAssertEqual(stateActions, [.login])
        XCTAssertEqual(environmentActions, [.login])
    }

    func testSerialServices() async throws {
        let cluster = try Bootstrap {
            Group {
                Reducer(state: _state,
                        context: _environment,
                        reduce: Reducers.record(service: .service1))
                Reducer(state: _state,
                        context: _environment,
                        reduce: Reducers.record(service: .service2))
            }
            .serial()
        }

        try await cluster.send(action: AccountAction.login)

        let stateActions = _state.actions
        let stateServices = _state.services
        let environmentActions = await _environment.actions
        let environmentServices = await _environment.services
        XCTAssertEqual(stateActions, [.login, .login])
        XCTAssertEqual(stateServices, [.service1, .service2])
        XCTAssertEqual(environmentActions, [.login, .login])
        XCTAssertEqual(environmentServices, [.service1, .service2])
    }

    func testStatelessReducer() async throws {
        let cluster = try Bootstrap {
            Reducer(context: _environment,
                    reduce: { _, action in
                        { _, environment in
                            await environment.add(action: action)
                        }
                    })
        }

        try await cluster.send(action: AccountAction.login)

        let environmentActions = await _environment.actions
        XCTAssertEqual(environmentActions, [.login])
    }
    
    func testReducerMiddleware() async throws {
        let store = Store<[AccountAction]>(initialState: [])
        
        let cluster = try Bootstrap {
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
            .pre { state, action in
                await store.update {
                    $0.append(action)
                }
            }
            .post { state, action in
                await store.update {
                    $0.append(action)
                }
            }
        }

        try await cluster.send(action: AccountAction.login)
        XCTAssertEqual(store.state, [.login, .login])
    }
    
    func testReducerMiddlewarePreThrow() async throws {
        let cluster = try Bootstrap {
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
            .pre { _, _ in
                throw AccountError.accessDenied
            }
        }

        do {
            try await cluster.send(action: AccountAction.login)
        }
        catch AccountError.accessDenied {
            return
        }
        
        XCTFail()
    }

    func testMultipleServices() async throws {
        let cluster = try Bootstrap {
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
            Reducer(state: _state,
                    context: _environment,
                    reduce: Reducers.record())
        }

        try await cluster.send(action: AccountAction.login)

        let stateActions = _state.actions
        let environmentActions = await _environment.actions
        XCTAssertEqual(stateActions, [.login, .login])
        XCTAssertEqual(environmentActions, [.login, .login])
    }

    func testErrorTransform() async throws {
        let cluster = try Bootstrap {
            Group {
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
        }

        try await cluster.send(action: AccountAction.login)

        let actions = _state.actions
        XCTAssertEqual(actions, [.login, .error])
    }
    
    func testCustomService() async throws {
        let cluster = try Bootstrap {
            AccountService()
        }
        
        try await cluster.send(action: AccountAction.login)
        
        let actions = _state.actions
        XCTAssertEqual(actions, [.login])
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
