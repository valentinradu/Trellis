# Trellis

[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-13-blue.svg?style=for-the-badge&logo=Xcode&logoColor=white)](https://developer.apple.com/xcode)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Trellis is a lightweight architectural framework inspired by Redux and the microservices architecture. It helps write clean, predictable, and above all, testable applications in Swift by favoring unidirectional data flow, separation of concerns and business logic encapsulation.
Trellis' philosophy is to be as non-intrusive as possible, exposing a single function (`dispatch`) to the presentation layer and having a very limited API surface otherwise.
Built on Swift concurrency model.

## Index
* [Installation](#installation)
* [Getting started](#getting-started)
* [Concurrency](#concurrency)
* [Testing](#testing)
* [License](#license)

## Installation

Using Swift Package Manager:
```
.package(name: "Trellis",
         url: "https://github.com/valentinradu/Trellis.git",
         .upToNextMinor(from: "0.1.0"))
```

## Getting started

### Services

Conceptually, services encapsulate the business logic and associated data. In a large scale application, each service handles a specific set of tasks that go together well. Trellis provides the means to easily build services and streamlines the service-to-service communication. 
Services are usually listed using an `enum`: 

```swift
enum Service {
    case starter
    case chords
    case account
    case logger
    case metronome
    case navigation
    case tuner
}
```

### The state

Each service owns its state, meaning no other entity can mutate it. However, it's common for the presentation layer to keep a reference to the state and watch for changes (readonly).

### The reducers

Reducers are functions that mutate the state in response to actions. Their signiature is `(inout State, Action) -> SideEffect?`, where the side effect is a function itself: `(Dispatch, Environment) -> Void`. Finally, `Dispatch` is a function as well: `(Action) -> Void`. It is a bit convoluted, but easier in practice and works great for injecting dependendecies during testing. A regular reducer looks something like this:


```swift
let reducer = { state, action in
    switch action {
        // Modify the state w.r.t. the action
        case .logout:
            state.loading = true
        // ...
    }
    
    // If additional, async operations are required,
    // return a side effect. 
    // Note: You cannot directly modify the state inside
    // side effects, but you can access it readonly.
    
    return { [state] dispatch, environment in
        // Do async work 
        await environment.logout(state.user.id)
        // Then, if required, dispatch again 
        // and repeat all the steps with another action 
        dispatch(action: .logoutComplete)
    }
}
``` 

Each service can can register multiple reducers, responding to different kind of actions.

### The environment

The environment is Trellis' dependency injection mechanism. It's only available inside the side effects and can hold references to external libraries, utils, the network layer, and so on.

### The structure

Trellis is very flexible and there are numerous ways to organize code around it. An approach that works great is to start with each service in a separate file containing the related actions, state, reducers, and the environment. Also, keeping all services in a separate module allows hiding information from the presentation layer.

```swift
// NavigationService.swift

public enum NavigationAction: Action {
    case goto(path: String)
    case back
}

public class NavigationState: ObservableObject {
    @Published public fileprivate(set) var path: String = ""
    @Published public fileprivate(set) var history: [String] = []
}

enum NavigationReducers {
    static var navigate: Reducer<EmptyEnvironment, NavigationState, NavigationAction> {
        return { state, action in
            switch action {
            case let .goto(path):
                state.history.append(state.path)
                state.path = path
            case .back:
                if state.history.count > 0 {
                    let path = state.history.removeLast()
                    state.path = path
                }
            }
            
            // We don't need any side effect in this case
            return .none
        }
    }
}

```

A few things to notice:

- the service has its own set of actions
- the state setter is `fileprivate`, only the service can mutate it
- only the state and actions are exposed outside of the module

This particular reducer doesn't have an environment, nor does it require additional side effects.

Once we have a service, we need to add it to the service pool. A service pool is a managed collection of services that can communicate with each other. In almost all cases, there's one pool per app.

```swift
let pool: ServicePool<Service> = .init()
let accountState: AccountState = .init()
let environment: AccountEnvironment = .init()

await pool
    .build(service: .account) // <-- this is the name from `Service` enum
    .set(initialState: state)
    .set(environment: environment)
    .add(reducer: AccountReducers.authentication)
    .bootstrap()
``` 

After we bootstrap all, we can pass the `pool.dispatch` function to any other entities that wish to indirectly mutate the state of our services (like the presentation layer). Trellis already declares a SwiftUI environment key for this:

```swift
var body: some Scene {
    return WindowGroup {
        AppView()
            .environmentObject(accountState)
            .environmentObject(navigationState)
            ...
            .environment(\.dispatch, pool.dispatch)
    }
}
```

Then other views can access the state and the `dispatch` function.

```swift
struct OtherView: View {
    @EnvironmentObject private var navigation: NavigationState
    @Environment(\.dispatch) private var dispatch
    // ...
    
    var body: some View {
        // ...
        Button(action: { 
            dispatch(action: NavigationAction.go(to: "/dashboard"))
        }) {
            Text(.later)
        }
    }
}
```

### Single service apps

For small apps, it could make sense to start with a single service and a couple of reducers instead of multiple services.

## Concurrency

Trellis uses the Swift concurrency model and guarantees that:

- all calls that mutate the state will be made on the main thread
- the `dispatch` function is reentrant and can be used from any thread

Side effects can be called on any thread, which usually means the environment should be an actor. 


## Testing

Unit testing is easy since reducers are pure functions and injecting dependencies into side effects is straightforward. To help with the former, Trellis provides `RecordDispatch` for recording all the dispatched actions (instead of passing them to services)

```swift
let dispatch = RecordDispatch()
let environment = MockedAccountEnvironment()
var state = AccountState()

if let sideEffect = AccountReducers.authentication(&state, AccountAction.login) {
    // Assert the resulting state
    // ...
    // Then perform the side effects
    try await sideEffect(dispatch, environment)
    // Assert the recorded actions and the state of the mocked environment
}
else {
    // Alternatively, assert if reducer returns any side effects 
}

```

## License
[MIT License](LICENSE)
