@testable import Dispatcher
import XCTest

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class DispatcherTests: XCTestCase {
    private var dispatcher: Dispatcher!
    private var playerService: PlayerService!
    private var gatekeeperService: GatekeeperService!
    private var middleware: TestMiddleware!

    override func setUp() {
        dispatcher = Dispatcher()

        // Normally, you'd inject both the state and a week reference to the dispatcher into services or middlewares (e.g. `playerService = PlayerService(state: state, dispatcher: dispatcher)`). In case you'd like to fire other actions as side effects to the ones that the service handles.
        playerService = PlayerService()
        gatekeeperService = GatekeeperService()
        middleware = TestMiddleware()

        dispatcher.register(worker: playerService)
        dispatcher.register(worker: gatekeeperService)
        dispatcher.register(middleware: middleware)
    }

    func testMiddlewareFirst() async throws {
        
    }
}
