//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Trellis
import XCTest

protocol Initializable {
    init()
}

enum TestError: Error, Equatable {
    case accessDenied
}



actor TestEnvironment: Initializable {}

enum AccountAction: Action, Equatable {
    case login(email: String)
    case newSession
    case error

    func transform(error: Error) -> TransfromErrorResult<Self> {
        .to(action: .error)
    }
}

struct AccountState: Initializable {
    fileprivate(set) var email: String = ""
}

typealias AccountServiceBuilder = ServiceBuilder<TestEnvironment, AccountState, AccountAction>

enum NavigationAction: Action, Equatable {
    case navigate(to: String)
    case error

    func transform(error: Error) -> TransfromErrorResult<Self> {
        .to(action: .error)
    }
}

struct NavigationState: Initializable {
    fileprivate(set) var path: String = ""
}

typealias NavigationServiceBuilder = ServiceBuilder<TestEnvironment, NavigationState, NavigationAction>

enum ServiceBuilder<E, S, A>
where E: Actor & Initializable, S: Initializable, A: Action
{
    static func bootstrap() async -> (E, Store<S>, Service<E, S>) {
        let store = Store(S())
        let environment = E()
        let service = Service(environment: environment,
                              store: store)
        return (environment, store, service)
    }

    static func fulfillReducer<A>(action: A) -> Reducer<E, S>
        where A: Action & Equatable
    {
        Reducer<E, S> { (_, incomingAction: A) -> _ in
            SideEffect { _, env in
                switch action {
                case incomingAction:
                    break
                default:
                    break
                }
            }
        }
    }

    static func errorReducer(error: Error) -> Reducer<E, S> {
        Reducer<E, S> { (_, _: A) -> _ in
            SideEffect { _, _ in
                throw error
            }
        }
    }
}
