# Trellis

[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-13-blue.svg?style=for-the-badge&logo=Xcode&logoColor=white)](https://developer.apple.com/xcode)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Trellis is a lightweight, declarative architectural framework inspired by Redux and the microservices architecture. It helps write clean, predictable, and above all, testable applications in Swift by favoring unidirectional data flow, separation of concerns and business logic encapsulation.
Trellis' philosophy is to be as non-intrusive as possible, exposing a single dispatch function to the presentation layer and having a very limited API surface otherwise.
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
         .upToNextMinor(from: "0.2.0"))
```

## Getting started

### Services

Conceptually, services encapsulate the business logic and associated data. In a large-scale application, each service handles a specific set of tasks that go together well. Trellis builds services using a DSL:

```swift
let cluster = try Bootstrap {
    Reducer(state: accountState,
            context: context,
            reduce: Reducers.account)
    Reducer(state: playerState,
            context: context,
            reduce: Reducers.player)
}

// ...

try await cluster.send(action: PlayerAction.play)
```

### The state

Each reducer service owns its state, meaning no other service should mutate it. However, it's common for the presentation layer to keep a reference to the state and watch for changes using a `post` modifier.

### The reducers

Reducers are services that mutate state in response to actions. Their reduce function signature is `(inout State, Action) -> SideEffect?`, where the side effect is a function itself: `(Dispatch, Context) -> Void`. Finally, `Dispatch` is a function as well: `(Action) -> Void`, used to publish new actions to the service cluster during the side effect. This works great for injecting dependencies and unit testing without touching the framework itself. A regular reduce function looks something like this:


```swift
typealias AccountReducer = Reducer<AccountState, AccountAction, AccountContext>

let reduce: AccountReducer.Reduce = { state, action in
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
    
    return { [state] dispatch, context in
        // Do async work 
        await context.logout(state.user.id)
        // Then, if required, dispatch again 
        // and repeat all the steps with another action 
        dispatch(action: .logoutComplete)
    }
}

// ...

let cluster = try Bootstrap {
    Reducer(state: state,
            context: context,
            reduce: reduce)
}
``` 

You can bootstrap 8 services at once, each responding to different kinds of actions. If you require more, you can group them or create custom services:

let cluster = try Bootstrap {
    Group {
        Reducer(state: state,
                context: context,
                reduce: reduce)
        // 7 more here
    }
    Group {
        Reducer(state: otherState,
                context: otherContext,
                reduce: otherReduce)
        // 7 more here
    }
    // ...
}

### The context

The context is Trellis' dependency injection mechanism. It's only available inside the side effects and can hold references to external libraries, utils, the network layer, and so on.

### The structure

Trellis is very flexible and there are numerous ways to organize code around it. An approach that works great for larger apps is to start with each service in a separate file containing the related actions, state, reducers, and the context. Also, keeping all services in a separate module allows hiding information from the presentation layer.

```swift
// NavigationService.swift

public typealias NavigationReducer = Reducer<NavigationState, NavigationAction, NavigationContext>

public enum NavigationAction: Action {
    case goto(path: String)
    case back
}

public struct NavigationState {
    public fileprivate(set) var path: String = ""
    public fileprivate(set) var history: [String] = []
}

public struct NavigationContext {
    fileprivate let analytics: ThirdPartyAnalytics
}

extension Reducers {
    static var navigate: NavigationReducer.Reduce {
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
            
            return { [state] _, context in
                context.analytics.event("navigation", state.path)
            }
        }
    }
}

// Bootstrap.swift

let cluster = try Bootstrap {
    Reducer(state: navigationState,
            context: navigationContext,
            reduce: Reducers.navigate)
}

```

A few things to notice:

- the service has its own set of actions
- the state setter is `fileprivate`, only the service can mutate it
- only the state and actions are exposed outside of the module

Alternatively, we could provide a custom service instead:

```swift
// NavigationService.swift

private struct NavigationStateKey: EnvironmentKey {
    static var defaultValue: NavigationState = .init()
}

private struct NavigationContextKey: EnvironmentKey {
    static var defaultValue: NavigationContext = .init()
}

extension EnvironmentValues {
    var navigationState: NavigationState {
        get { self[NavigationStateKey.self] }
        set { self[NavigationStateKey.self] = newValue }
    }

    var navigationContext: NavigationContext {
        get { self[NavigationContextKey.self] }
        set { self[NavigationContextKey.self] = newValue }
    }
}

struct NavigationService: Service {
    @Environment(\.navigationState) private var _state
    @Environment(\.navigationContext) private var _context

    var body: some Service {
        Reducer(state: _state,
                context: _context,
                reduce: Reducers.navigate)
    }
}

// Bootstrap.swift

let cluster = try Bootstrap {
    NavigationService()
        .environment(\.navigationState, value: state)
        .environment(\.navigationContext, value: context)
}
```

After bootstrap, we can pass the `cluster.send` function to any other entities that wish to indirectly mutate the state of our services (like the presentation layer).

### Single reducer apps

For small apps, it could make sense to start with a single reducer and grow from there.

## Concurrency

Trellis uses the Swift concurrency model and guarantees that:

- all calls that mutate the state will be made on the main thread
- the `cluster.send` function is reentrant and can be used from any thread

Side effects can be called on any thread, which means the context should be an actor. 


## Testing

Unit testing is easy since reducing functions are pure and injecting dependencies into side effects is straightforward. To help with the former, Trellis provides `RecordDispatch` for recording all the dispatched actions (instead of passing them to services)

```swift
let dispatch: Dispatch = { action in
    // record actions here
}
let context = MockedAccountContext()
var state = AccountState()

if let sideEffect = Reducers.account(&state, .login) {
    // Assert the resulting state
    // ...
    // Then perform the side effects
    try await sideEffect(dispatch, context)
    // Assert the recorded actions and the state of the mocked context
}
else {
    // Alternatively, assert if reducer returns any side effects 
}

```

## License
[MIT License](LICENSE)
