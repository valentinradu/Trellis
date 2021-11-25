# Dispatcher


Dispatcher is a zero-dependency architectural framework that helps you write clean, predictable, testable applications in Swift. 


## Features

- expressive, compact and easy to use API
- built for `iOS`, `macOS`, `tvOS`, `macCatalyst`, `watchOS` and `driverKit`
- full middleware support
- zero library dependencies
- supports redirects and deffered calls
- full action history
- works with legacy callbacks, `Combine` and/or `await/async` 
- tested, coverage 100%

## Core Concepts

There are 4 actors that work together in Dispatcher: `Action`s, `Middleware`s, `Worker`s and the `Dispatcher`. The first 3 are protocols 

### Actions

Actions drive all the other actors and are usually the first thing we define. They model all the possible events that your application can handle. Also, when fired, most of them will lead to a state mutation.

 ```
 /// An example of 3 actions fired by a simple authentication
 enum GatekeeperAction: Action, Equatable {
     case login(email: String, password: String)
     case logout
     case resetPassword
 }
 ```

### Middlewares

### Workers

### The Dispatcher

## Common patterns

### Blocking an action

### Postponing an action

### Identifying actions by name

## Multi-threading
