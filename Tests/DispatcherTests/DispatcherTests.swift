@testable import Dispatcher
import XCTest

class State {}

enum PlayerAction: Action {
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
        }
    }
}

extension ActionGroup {
    static var account: ActionGroup<PlayerAction> {
        .init(.fetchAccount, .patchEmail, .registerNewDevice)
    }

    static var player: ActionGroup<PlayerAction> {
        .init(.load, .play, .stop, .skip)
    }

    static var authenticated: ActionGroup<PlayerAction> {
        .account.and(.player)
    }

    static var admin: ActionGroup<PlayerAction> {
        .init(.closeAccount)
    }
}

/// To make things easier to follow, the tests are working with a set of toy actions that emulate an app that has authentication, both as a regular user and admin, a simple audio player available only to authenticated users and a set of admin-specific actions.
final class DispatcherTests: XCTestCase {
    func testExample() throws {
        let dispatcher = Dispatcher()
        dispatcher.fireAndForget(PlayerAction.play)
    }
}
