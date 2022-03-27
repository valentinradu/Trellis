# Trellis

[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-13-blue.svg?style=for-the-badge&logo=Xcode&logoColor=white)](https://developer.apple.com/xcode)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Trellis is a zero-dependency, architectural framework inspired by Redux and the microservices architecture. It can help you write clean, predictable, and above all, testable applications in Swift. It favors unidirectional data flow, separation of concerns and supports Swift 5.6+ concurrency.
Trellis' philosophy is to be as non-intrusive as possible, exposing a single function (`dispatch`) to the presentation layer and having a very limited API surface otherwise.

## Index
* [Installation]
* [Getting started](#getting-started)
* [Concurrency](#concurrency)
* [Testing](#testing)
* [License](#license)

## Installation

Using Swift Package Manager:
```
.package(name: "Trellis",
         url: "https://github.com/valentinradu/Trellis.git",
         .upToNextMinor(from: "1.0.0"))
```

## Getting started

### Services

Conceptually, services encapsulate the business logic and its associated data. In a large scale application, each service handles a specific set of tasks that go together well. Trellis provides the means to easily build services and streamlines the service-to-service communication. Services are usually listed using an `enum`: 

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

Reducers are functions that mutate the state as a response to an action. Their signiature is `(inout State, Action) -> SideEffect`. They take the current state, and mutates it w.r.t. the action while returning any other additional tasks that need to be performed as a side effect. 
While each service can only have one state, it can register multiple reducers, responding to different kind of actions.

### The environment

The environment is Trellis' dependency injection mechanism. It's only available inside the side effects and can hold references to external libraries, utils, the network layer, and so on.

Trellis is flexible and there are numerous ways to organize code around it. An approach that works great is to start with each service in a separate file and declare the related actions, state, reducers, and environment in it. 

```swift
// NavigationService.swift

enum NavigationAction: Action {
    case goto(path: String)
    case back
}

class NavigationState: ObservableObject {
    @Published fileprivate(set) var path: String = ""
    @Published fileprivate(set) var history: [String] = []
}

extension Reducer
    where E == EmptyEnvironment, S == NavigationState, A == NavigationAction
{
    static var navigation: Reducer {
        Reducer { state, action in
            switch action {
            case let .goto(path):
                state.history.append(state.path)
                state.path = path
            case let .back:
                if state.history.count > 0 {
                    let path = state.history.removeLast()
                    state.path = path
                }
            }
            
            return .none
        }
    }
}

```

A few things to notice:

- the service has its own set of actions that are handled inside the reducer
- the state setter is `fileprivate`, only the service can write to it
- declaring reducers in a `Reducer` extension will make it easier passing it to `.add(reducer:)`

This particular reducer doesn't have an environment, nor does it require additional side effects. A reducer with side effects and an environment would have looked like this (notice how we return the side effect instead of `.none`):

```swift
extension Reducer
    where E == AccountEnvironment, S == AccountState, A == AccountAction
{
    static var account: Reducer {
        Reducer { state, action in
            switch action {
            case .logout
                state.user = .guest
                return SideEffect { dispatch, environment in
                    dispatch(action: NavigationAction.go(to: "/"))
                    await environment.remote.logout()
                }
            }
        }
    }
}
```

Once we have a service, we need to add it to a service pool. A service pool is a managed collection of services that can communicate with each other. In almost all cases, there's one pool per app.

```swift
let pool: ServicePool<Service> = .init()
let accountState: AccountState = .init()
let environment: AccountEnvironment = .init()

await pool
    .build(service: .account) // <-- this is the name from `Service` enum
    .set(initialState: state)
    .set(environment: environment)
    .add(reducer: .account) // <-- this is the reducer from the extension
    .bootstrap()
``` 

Once we bootstrap all our services, we can pass the `pool.dispatch` function to any other entities that wish to indirectly mutate the state of our services (like the presentation layer). Trellis already declares a SwiftUI environment key for this:

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

## Concurrency

Trellis uses the Swift 5.6 concurrency model and guarantees that:

- all calls that mutate the state will be made on the main thread
- the `dispatch` function is reentrant and can be used from any thread
- the environment can be called from any thread (it has to be an actor)


## Testing

Unit testing with Trellis is really easy since reducers are pure functions and injecting dependencies into side effects is straightforward. 
TODO: Expand on this, add an example.
  

## License
[MIT License](LICENSE)
