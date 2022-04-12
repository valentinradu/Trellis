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
        let cluster = try await Bootstrap {
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

    func testStateWatchers() async throws {
        let store = MutableRef<[AccountState]>([])

        let cluster = try await Bootstrap {
            Group {
                Reducer(state: _state,
                        context: _context,
                        reduce: Reducers.record())
            }
            .watch(AccountState.self) { state in
                store.value.append(state)
            }
        }

        try await cluster.send(action: AccountAction.login)

        XCTAssertEqual(store.value.first, _state)
    }

    func testSerialServices() async throws {
        let cluster = try await Bootstrap {
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

    func testEmitter() async throws {
        let stream = AsyncStream<any Action> { continuation in
            for action in [AccountAction.login, AccountAction.error] {
                continuation.yield(action)
            }
            continuation.finish()
        }

        _ = try await Bootstrap {
            Emitter(stream: stream) {
                Reducer(state: _state,
                        context: _context,
                        reduce: Reducers.record())
            }
            .consume()
        }

        let contextActions = await _context.actions
        XCTAssertEqual(contextActions, [.login, .error])
    }

    func testStatelessReducer() async throws {
        let cluster = try await Bootstrap {
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

    func testMultipleServices() async throws {
        let cluster = try await Bootstrap {
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
        let cluster = try await Bootstrap {
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
        let cluster = try await Bootstrap {
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
        let store = MutableRef<[AccountAction]>([])
        let dispatch = { (action: any Action) async throws in }
        let reducer = Reducers.record()
        let context = AccountContext()
        var state = AccountState()
        if let sideEffect = reducer(&state, .login) {
            try await sideEffect(dispatch, context)
        }

        let dispatchActions = store.value
        let reducerActions = state.actions
        let contextActions = await context.actions

        XCTAssertEqual(dispatchActions, [])
        XCTAssertEqual(reducerActions, contextActions)
    }
}
