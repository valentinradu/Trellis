# Trellis

[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg?style=for-the-badge&logo=swift)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-13-blue.svg?style=for-the-badge&logo=Xcode&logoColor=white)](https://developer.apple.com/xcode)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

Trellis is a non-intrusive, zero-dependency, architectural framework that helps you write clean, predictable, testable applications in Swift. It favors unidirectional data flow, separation of concerns, and data encapsulation.

## Index
* [Installation]
* [Getting started](#getting-started)
* [Multi-threading](#multi-threading)
* [Testing](#testing)
* [License](#license)

## Installation

Using Swift Package Manager:
```
.package(name: "Trellis",
         url: "https://github.com/valentinradu/Trellis.git",
         .upToNextMinor(from: "1.0.0"))
```

## Core Concepts

### Services

Services encapsulate the business logic and its associated data. Each service should handle a specific set of tasks that go together well, like authentication, account, prefetching, persistence, various repositories (article, users, likes, etc), and so on. 

```swift

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

### The Dispatcher

The dispatcher is the entry point, a mediator, the entity that allows services to communicate with each other.

## Multi-threading

Trellis expects all its methods to be called on the same thread (usually the main thread). However, since the `receive(action:)` method of the service is async, you can always offload the work to multiple threads as long as you return to the same thread before returning the result (e.g. using `receive(on:)` in `Combine`)



## License
[MIT License](LICENSE)
