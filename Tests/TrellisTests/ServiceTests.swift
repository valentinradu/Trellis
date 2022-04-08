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
    private var _context: AccountContext!

    override func setUp() async throws {
        _state = AccountState()
        _context = AccountContext()
    }

    func testSingleService() async throws {
        let cluster = try Bootstrap {
            Reducer(state: _state,
                    context: _context,
                    reduce: Reducers.record())
        }

        try await cluster.send(action: AccountAction.login)

        let stateActions = _state.actions
        let contextActions = await _context.actions
        XCTAssertEqual(stateActions, [.login])
        XCTAssertEqual(contextActions, [.login])
    }

    func testSerialServices() async throws {
        let cluster = try Bootstrap {
            Group {
                Reducer(state: _state,
                        context: _context,
                        reduce: Reducers.record(service: .service1))
                Reducer(state: _state,
                        context: _context,
                        reduce: Reducers.record(service: .service2))
            }
            .serial()
        }

        try await cluster.send(action: AccountAction.login)

        let stateActions = _state.actions
        let stateServices = _state.services
        let contextActions = await _context.actions
        let contextServices = await _context.services
        XCTAssertEqual(stateActions, [.login, .login])
        XCTAssertEqual(stateServices, [.service1, .service2])
        XCTAssertEqual(contextActions, [.login, .login])
        XCTAssertEqual(contextServices, [.service1, .service2])
    }

    func testStatelessReducer() async throws {
        let cluster = try Bootstrap {
            Reducer(context: _context,
                    reduce: { _, action in
                        { _, context in
                            await context.add(action: action)
                        }
                    })
        }

        try await cluster.send(action: AccountAction.login)

        let contextActions = await _context.actions
        XCTAssertEqual(contextActions, [.login])
    }
    
    func testReducerMiddleware() async throws {
        let store = Store<[AccountAction]>(initialState: [])
        
        let cluster = try Bootstrap {
            Reducer(state: _state,
                    context: _context,
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
                    context: _context,
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
                    context: _context,
                    reduce: Reducers.record())
            Reducer(state: _state,
                    context: _context,
                    reduce: Reducers.record())
        }

        try await cluster.send(action: AccountAction.login)

        let stateActions = _state.actions
        let contextActions = await _context.actions
        XCTAssertEqual(stateActions, [.login, .login])
        XCTAssertEqual(contextActions, [.login, .login])
    }

    func testErrorTransform() async throws {
        let cluster = try Bootstrap {
            Group {
                Reducer(state: _state,
                        context: _context,
                        reduce: Reducers.error(.accessDenied, on: .login))
                Reducer(state: _state,
                        context: _context,
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
        let otherState = AccountState()
        let otherContext = AccountContext()
        let cluster = try Bootstrap {
            AccountService()
                .environment(\.accountContext, value: otherContext)
                .environment(\.accountState, value: otherState)
        }
        
        try await cluster.send(action: AccountAction.login)
        
        let stateActions = otherState.actions
        let contextActions = await otherContext.actions
        XCTAssertEqual(stateActions, [.login])
        XCTAssertEqual(contextActions, [.login])
    }

    func testDirectAccess() async throws {
        let store = Store<[AccountAction]>(initialState: [])
        let dispatch = { (action: any Action) async throws in }
        let reducer = Reducers.record()
        let context = AccountContext()
        var state = AccountState()
        if let sideEffect = reducer(&state, .login) {
            try await sideEffect(dispatch, context)
        }

        let dispatchActions = store.state
        let reducerActions = state.actions
        let contextActions = await context.actions

        XCTAssertEqual(dispatchActions, [])
        XCTAssertEqual(reducerActions, contextActions)
    }
}
