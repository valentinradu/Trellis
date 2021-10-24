@testable import Dispatcher
import XCTest

class State {}

enum TestAction: Action {
    // Authentication
    case login(email: String, password: String)
    case logout
    case resetPassword

    // Account management
    case fetchAccount
    case patchEmail(value: String)
    case registerNewDevice(id: String)

    // Player
    case load(url: URL)
    case play
    case stop
    case skip(duration: Double)

    // Admin
    case closeAccount

    // UI
    case alert(error: Error)
    case nav(path: String)

    // This section is required because Swift doesn't synthetize the **name** of the enum and we can't use the enum itself since some have associated values (e.g. `.login(email: String, password: String)`
    enum Name {
        case login
        case logout
        case resetPassword
        case fetchAccount
        case patchEmail
        case registerNewDevice
        case load
        case play
        case stop
        case skip
        case closeAccount
        case alert
        case nav
    }

    var name: Name {
        switch self {
        case .login: return .login
        case .logout: return .logout
        case .resetPassword: return .resetPassword
        case .fetchAccount: return .fetchAccount
        case .patchEmail: return .patchEmail
        case .registerNewDevice: return .registerNewDevice
        case .load: return .load
        case .play: return .play
        case .stop: return .stop
        case .skip: return .skip
        case .closeAccount: return .closeAccount
        case .alert: return .alert
        case .nav: return .nav
        }
    }
}

extension ActionGroup {
    static var accountGroup: ActionGroup<TestAction> {
        .init(.fetchAccount, .patchEmail, .registerNewDevice)
    }

    static var playerGroup: ActionGroup<TestAction> {
        .init(.load, .play, .stop, .skip)
    }

    static var authenticatedGroup: ActionGroup<TestAction> {
        .accountGroup.and(.playerGroup)
    }

    static var adminGroup: ActionGroup<TestAction> {
        .init(.closeAccount)
    }
}

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
class PlayerService: Worker {
    fileprivate var actions: [TestAction] = []

    func execute(_ action: TestAction) async throws {
        if action.in(group: .playerGroup) {
            await Task.sleep(UInt64(0.3 * Double(NSEC_PER_SEC)))
            actions.append(action)
        }
    }
}

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
class GatekeeperService: Worker {
    fileprivate var actions: [TestAction] = []

    func execute(_ action: TestAction) async throws {
        if action.in(group: .authenticatedGroup) {
            await Task.sleep(UInt64(0.3 * Double(NSEC_PER_SEC)))
            actions.append(action)
        }
    }
}

@available(iOS 15.0, watchOS 8.0, tvOS 15.0, *)
class TestMiddleware: Middleware {
    enum AuthState {
        case unauthenticated
        case authenticated
        case admin
    }

    var authState: AuthState = .unauthenticated

    func `defer`(action: TestAction) -> Deferral<TestAction> {
        // If account is unauthenticated but the action requires authentication, look behind, if login action was already fired, fire your action, if not, wait until it is and then fire your action
        if authState == .unauthenticated,
           action.in(group: .authenticatedGroup)
        {
            return .lookBehind(name: .login)
        }

        // If we have to register the device id, check if the account is unauthenticated, if so, look behind in history and fire `.registerNewDevice` either right away, if `.login` was already fired, or right after `.login` fires.
        // Alternatively, if the account is already authenticated, wait for `.fetchAccount` and fire right after it
        if action.name == .registerNewDevice {
            if authState == .unauthenticated {
                return .lookBehind(name: .login)
            }
            else {
                return .lookAhead(name: .fetchAccount)
            }
        }

        return .none
    }

    func redirect(action: TestAction) -> Redirection<TestAction> {
        // If the account is not authenticated but we try to fire an action that require authentication, navigate the user to the login page (we'd normally also clear the  state here)
        if authState == .unauthenticated,
           action.in(group: .authenticatedGroup)
        {
            return .to(action: .nav(path: "/login"))
        }

        return .none
    }
}

/// To make things easier to follow, the tests are working with a set of toy actions that emulate an app that has authentication, both as a regular user and admin, a simple audio player available only to authenticated users and a set of admin-specific actions.
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

    func testExample() async throws {}
}
