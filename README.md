# Trellis

[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-13-blue.svg?style=for-the-badge&logo=Xcode&logoColor=white)](https://developer.apple.com/xcode)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Trellis features a declarative DSL that simplifies service bootstrapping: 

```swift
let cluster = try await Bootstrap {
    Group {
        Store(model: IdentityModel.self)
            .mutate(on: IdentityAction.self) { model, action, send in
                // ...
            }
            .mutate(on: StartUpAction.self) { model, action, send in
                // ...
            }
            .with(model: identityModel)
        Store(model: ArticlesModel.self)
            .mutate(on: ArticlesAction.self) { model, action, send in
                // ...
            }
            .with(model: articlesModel)
    }
    .emit(using: notificationsStream)
    .transformError {
        ErrorAction.error($0)
    }
    .observe(on: IdentityAction.self) {
        // ...
    }
}
```

This sets up two services managing the identity of the user and his articles. The resulting cluster exposes only one function, `send`, which can be used to interact with the services without explicitly know which service handles which action.

```swift
try await cluster.send(action: StartUpAction.appDidCompleteLaunching)
```

Most of the time we won't declare services like this. Instead, we'd write a custom service wrapping each store:

```swift
// IdentityService.swift
struct IdentityService: Service {
    var body: some Service {
        Store(model: IdentityModel.self)
            .mutate(on: IdentityAction.self) { model, action, send in
                // ...
            }
            .mutate(on: StartUpAction.self) { model, action, send in
                // ...
            }
    }

// SomeOtherFile.swift
let cluster = try await Bootstrap {
    IdentityService()
        .with(model: identityModel)
}
```

Notice how the actual model is injected from outside the service, enabling dependency injection.

## Index
* [Installation](#installation)
* [Getting started](#getting-started)
* [Concurrency](#concurrency)
* [Modifiers](#modifiers)
* [Testing](#testing)
* [License](#license)

## Installation

Using Swift Package Manager:
```
.package(name: "Trellis",
         url: "https://github.com/valentinradu/Trellis.git",
         .upToNextMinor(from: "0.3.0-beta"))
```

## Getting started

### Actions and services

Services are entities that react to actions. They form a tree-like structure that allows each parent service to delegate actions to its children. Most of the entities in Trellis are services. 

### Modifiers

Modifiers change the behavior of a service. Most modifiers, like `.serial()` will traverse the service tree and apply to all sub-services under it, while some, like `.mutate(on:)` only make sense when applied to the service immediately under it. For more info about modifiers check the appropriate section below.

### Groups

Groups are inert services that pass actions to their children without taking any other additional steps. They're mostly used to apply a modifier (e.g. `emit(using:consumeAtBootstrap:)`) to multiple services or to bypass the number of maximum sub-services (8) a service can have.

### Stores

Each store encapsulates a model, which in turn, handles a set of tasks (and their associated data) that go together well. Stores allow you to use and mutate the wrapped model each time an action is sent to the cluster.

## Modifiers

`.emit(using:consumeAtBootstrap:)` - Takes an external source of events (async stream) that outputs actions and feeds them to all services under it. When setting `

`.transformError(transformHandler:)` - Turns all errors originating from services under it into actions and feeds them back into the cluster. If the transformed error throws again, the operation will fail and the `send(action:)` function with throw.

`.concurrent()` - Executes all services under it in a concurrent fashion. This is the default.

`.serial()` - Executes all services under it one after the other. Ideal for cases where you want to something, like the identity of the user, before allowing other services to process the action.

`.bootstrap(bootstrapHandler:)` - Called right after service creation, it gives services the possibility to initialize state or bootstrap models before handling any actions.

`.observe(observeHandler:)` - Called each time an action is received. Ideal for logging and updating external (e.g. presentation layer) state.

`.mutate(on:mutateHandler:)` - Called each time an action is received. Inside the handler you can mutate the model depending on the received action and send other actions to further processing.

`.with(model:)` - Sets the model for all sub-services under it.

## Concurrency

Trellis uses the Swift concurrency model and guarantees that the services will be always built and bootstrapped on the main thread. There is on other guarantee, and for this reason, all models should be actors.

## Testing

With Trellis, unit testing is mostly focused around the models. However, if you wish to also test the service integration, it's easy to do so. You can simply replace the model with a mocked version and the cluster send function with one that records actions instead:

```swift
// SomeTest.swift
let cluster = try await Bootstrap {
    IdentityService()
        .with(model: mockedIdentityModel)
        .environment(\.send, recordingSend)
}

try await cluster.send(action: StartUpAction.appDidCompleteLaunching)
// Assert the state of the mocked identity model and the recorded actions
```

## License
[MIT License](LICENSE)
