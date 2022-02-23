# Trellis

[![Swift](https://img.shields.io/badge/Swift-5.3-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-13-blue.svg?style=for-the-badge&logo=Xcode&logoColor=white)](https://developer.apple.com/xcode)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Trellis is a zero-dependency architectural framework that helps you write clean, predictable, testable applications in Swift. Inspired by the microservices architecture, it favors unidirectional data flow, separation of concerns, and business logic and data encapsulation.

## Index
* [Features](#features)
* [Core Concepts](#core-concepts)
* [Common patterns](#common-patterns)
* [Multi-threading](#multi-threading)
* [Example](#example)
* [License](#license)

## Features

- expressive, compact API
- full middleware support
- zero library dependencies
- supports redirects and deferred calls
- full action history
- works with legacy callbacks, `Combine` and/or `await/async`
- built for `iOS`, `macOS`, `tvOS`, `macCatalyst`, `watchOS` and `driverKit` 
- fully tested

## Core Concepts

### Services

Services encapsulate the business logic and its associated data. Each service should handle a specific set of tasks that go together well, like authentication, profile, prefetching, persistence, various (article, users, likes, etc) repositories, and so on. Services perform these tasks when receiving actions inside `receive(action:)`. `receive(action:)` supports calling async code allowing you to offload work to other threads (e.g. when making network requests).

```swift
// GatekeeperService.swift
// An authentication service
class GatekeeperService: Service {
    func receive(_ action: GatekeeperAction) async throws -> ActionFlow<AnyAction> {
        switch action {
        case let .login(username, password):
            // make the server login call, update the gatekeeper state etc
        case .logout:
            // clear state, reset the dispatcher, remove any user-persisting data etc
            // ...
        }
        
        return .noop
    }
}
```

### Actions

Actions model all the possible events that a service can handle.

 ```swift
 // GatekeeperService.swift
 // Actions are typically declared inside the service that handles them
 // An example of 3 actions used to authenticate a user
 enum GatekeeperAction: Action {
     case login(email: String, password: String)
     case logout
     case resetPassword
 }
 ```

### Middlewares

Middlewares are getting called before *any* of the services start processing an action (`pre(action)`) and after all the services finished processing an action (`post(action)`).

- The `pre(action:)` method is called before the services start processing an action and it's mostly used to redirect the action to another action flow.
- The `post(action:)` method is called after all the services finished processing the action.
- The `failure(action:, error:)` method is called when any of the services raise an error.

```swift
// An example of a middleware blocking all user actions until an authenticated user is present 

enum UserAction: Action {
case fetchArticles
case fetchFavs
case update(username: String)
// ...
// `.noop` is a special action that's ignored by everybody
case noop
}

func pre(action: UserAction) throws -> Rewrite<UserAction> {
    if state.user == .unauthenticated {
        return .redirect(to: .single(action: .noop))
    }
}
```

### The Dispatcher

The dispatcher is the entry point, a mediator, the entity that allows services to communicate with each other.

## Common patterns

### Blocking an action

There is no built-in way to block an action, one of the rules Trellis follows is: once an action is sent, it will always either complete or fail. This is keeping everything consistent and predictable and it's helpful for debugging. However, it's trivial to add a `.noop` action that gets ignored by all your services. Redirecting to this `.noop` action in the middleware will behave like you're blocking current the action while keeping things predictable and consistent. 

```swift
// Blocking actions when the user is not authenticated
func pre(action: UserAction) throws -> Rewrite<UserAction> {
    // If user is not authenticated, redirect to `.noop` and do nothing
    if state.user == .unauthenticated {
        return .redirect(to: .single(action: .noop))
    }
}
```

### Postponing an action

There is no built-in way to postpone an action, however, just like with blocking actions, one can have a `.postpone(action:)` action that stacks actions in an `ActionFlow` until a certain other action is sent.

```swift
// Postponing an action until the user is authenticated

var postponedActions: ActionFlow<UserAction> = .noop()

func pre(action: UserAction) throws -> Rewrite<UserAction> {
    switch action.name {
    // If the user logged in, redirect to a flow that contains the initial action, plus all the other actions that were postpone until login
    case .accountReady:
        .redirect(to: action.then(flow: postponedActions))
    default:
        break
    }
    
    // If the user is not authenticated yet, postpone all the actions
    if state.user == .unauthenticated {
        return .redirect(to: .single(action: .postpone(action)))
    }
}

// In the `post(action:)` methods we simply collect all the action that await logging it.
func post(action: TestAction) {
    switch action {
    case let .postpone(other):
        postponedActions = postponedActions.then(other)
    default:
        break
    }
}
```

## Multi-threading

Trellis expects all its methods to be called on the same thread (usually the main thread). However, since the `receive(action:)` method of the service is async, you can always offload the work to multiple threads as long as you return to the same thread before returning the result (e.g. using `receive(on:)` in `Combine`)

## Example

```swift
// GatekeeperService.swift
// An enum containing all the actions (events) the gatekeeper service can handle
enum GatekeeperAction: Action {
    case login(email: String, password: String)
    case logout
    case resetPassword
}

// The gatekeeper state. It can be read by other services, but only 
// this service is allowed to mutate it
private struct GatekeeperStateKey: DependencyKey {
    static var value: GatekeeperState = .main
}

public extension DependencyRepository {
    fileprivate(set) var gatekeeperState: GatekeeperState {
        get { self[GatekeeperStateKey.self] }
        set { self[GatekeeperStateKey.self] = newValue }
    }
}

// A class that receives all actions before the service
// (before the action gets processed) and has the opportunity 
// to redirect it to another action. Middlewares, like services, 
// have access to the state. 
class GatekeeperMiddleware: Middleware {
    @Dependency(\.gatekeeperState) var state
    
    func pre(action: GatekeeperAction) throws -> Rewrite<AnyAction> {
        // If the user is not authenticated, we can redirect to `.noop` 
        // which is an action not handled by any of the services, 
        // essentially stoping the processing flow.
        if state.user == .unauthenticated {
            return .redirect(to: .single(action: .noop))
        }
    }
}

// The service is handling all authentication-related actions. 
// It can offload work to secondary threads, handle business logic, 
// delegate work to other services and so on. Each action here usually 
// mutates the state. It returns an action flow if other actions need executing 
// right after the current one, or `.noop`. 
class AuthService: Service {
    @Dependency(\.gatekeeperState) var state
        
    func receive(_ action: AppAction) async throws -> ActionFlow<AppAction> {
        switch action {
        case let .login(username, password):
            // ...
            // make the server login call
            // update the state after login
            state.user == .authenticated(user)
        case .logout:
            // clear state, reset the dispatcher, 
            // remove any user-persisting data etc
        case resetPassword:
            // make the server reset password call
        }
        
        return .noop
    }
}
```

## License
[MIT License](LICENSE)
