import XCTest
@testable import Dispatcher

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class MiddlewareTests: XCTestCase {
    private var dispatcher: Dispatcher!
    private var service: TestService!
    private var middleware: TestMiddleware!

    override func setUp() {
        dispatcher = Dispatcher()

        // Normally, you'd inject both the state and a week reference to the dispatcher into services or middlewares (e.g. `playerService = PlayerService(state: state, dispatcher: dispatcher)`). In case you'd like to fire other actions as side effects to the ones that the service handles.
        service = TestService()
        middleware = TestMiddleware()

        dispatcher.register(worker: service)
        dispatcher.register(middleware: middleware)
    }

    func testMiddlewareSuccess() async throws {
        middleware.authState = .authenticated
        try await dispatcher.fire(TestAction.play)

        // Workers and middleware got the action
        XCTAssertEqual(middleware.preActions.map(\.1), [.play])
        XCTAssertEqual(middleware.postActions.map(\.1), [.play])
        XCTAssertEqual(service.actions.map(\.1), [.play])
        XCTAssertEqual(middleware.failures.map(\.1), [])

        // Workers and middleware got the action in the right order
        XCTAssertLessThan(middleware.preActions[0].0, service.actions[0].0)
        XCTAssertLessThan(service.actions[0].0, middleware.postActions[0].0)
    }

    func testMiddlewareFailure() async throws {
        middleware.authState = .admin
        try await dispatcher.fire(TestAction.closeAccount)
        XCTAssertEqual(middleware.postActions.map(\.1), [.closeAccount])

        middleware.authState = .authenticated
        try await dispatcher.fire(TestAction.closeAccount)

        // Workers and middleware got the action only in the right stage
        XCTAssertEqual(middleware.preActions.map(\.1), [.closeAccount])
        XCTAssertEqual(middleware.postActions.map(\.1), [])
        XCTAssertEqual(service.actions.map(\.1), [])
        XCTAssertEqual(middleware.failures.map(\.1), [.closeAccount])
        XCTAssertEqual(middleware.failures.map { $0.2 as? TestError },
                       [TestError.accessDenied])

        // The action went from a stage to another in the right order
        XCTAssertLessThan(middleware.preActions[0].0, middleware.failures[0].0)
    }

    func testMiddlewareNoRewrite() async throws {
        middleware.authState = .authenticated
        try await dispatcher.fire(TestAction.logout)

        XCTAssertEqual(service.actions.map(\.1), [.logout])
    }

    func testMiddlewareRedirect() async throws {
        middleware.authState = .unauthenticated
        try await dispatcher.fire(TestAction.play)

        XCTAssertEqual(service.actions.map(\.1), [.logout])
    }

    func testMiddlewareWaitForOthers() async throws {
        middleware.authState = .unauthenticated
        try await dispatcher.fire(TestAction.registerNewDevice(id: ""))

        // `.registerNewDevice` should not be called until authenticated
        XCTAssertEqual(service.actions.map(\.1), [])

        middleware.authState = .authenticated
        try await dispatcher.fire(TestAction.login(email: "", password: ""))

        // `.registerNewDevice` should only be called if `.fetchAccount` was already called, or, if not, right after it
        XCTAssertEqual(service.actions.map(\.1.name), [.login])

        try await dispatcher.fire(TestAction.fetchAccount)

        XCTAssertEqual(service.actions.map(\.1.name),
                       [.login, .fetchAccount, .registerNewDevice])
        XCTAssertLessThan(service.actions[0].0, service.actions[1].0)
    }

    func testMiddlewareQueueActionsUntilOther() async throws {
        middleware.authState = .unauthenticated
        try await dispatcher.fire(TestAction.fetchAccount)
        try await dispatcher.fire(TestAction.registerNewDevice(id: ""))

        middleware.authState = .authenticated
        try await dispatcher.fire(TestAction.login(email: "", password: ""))

        XCTAssertEqual(service.actions.map(\.1.name),
                       [.login, .fetchAccount, .registerNewDevice])
    }

    func testMiddlewareWaitOnlyForFutureOthers() async throws {
        middleware.authState = .authenticated
        try await dispatcher.fire(TestAction.login(email: "", password: ""))

        try await dispatcher.fire(
            TestAction
                .fetchAccount
                .then(other: .registerNewDevice(id: ""))
        )

        XCTAssertEqual(service.actions.map(\.1.name),
                       [.login, .fetchAccount])
    }
}
