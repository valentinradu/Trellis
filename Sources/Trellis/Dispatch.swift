//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

/**
 The dispatch sends actions to all services and schedules their side effects.
  */
public protocol Dispatch {
    @MainActor
    func callAsFunction<A>(action: A) where A: Action
}

/**
 Reducers react to **actions** and mutate the state in a predictable way.
 ```
 enum AccountAction: Action {
     case login(email: String, password: String)
     case logout
     case resetPassword
 }
 ```
 */
public protocol Action: Hashable {}

public struct AnyAction: Action {
    public let base: Any
    private let _hash: (inout Hasher) -> Void

    init<A>(_ action: A) where A: Action {
        base = action
        _hash = { hasher in
            action.hash(into: &hasher)
        }
    }

    public static func == <A>(lhs: Self, rhs: A) -> Bool
        where A: Action
    {
        if let lhs = lhs as? A ?? lhs.base as? A {
            return lhs == rhs
        }
        else {
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        _hash(&hasher)
    }
}

/**
 A dispatch that records actions.
 */
public class RecordDispatch: Dispatch {
    @MainActor
    public private(set) var actions: [AnyAction] = []

    @MainActor
    public func callAsFunction<A>(action: A) where A: Action {
        actions.append(AnyAction(action))
    }
}

actor ServiceDispatch: Dispatch {
    private var _services: [AnyHashable: Reactive] = [:]
    @MainActor private var _tasks: [AnyHashable: Task<Void, Never>] = [:]

    func registerService<N>(_ service: Reactive, name: N) where N: ServiceName {
        _services[name] = service
    }

    func unregisterService<N>(_ name: N) where N: ServiceName {
        _services.removeValue(forKey: name)
    }

    @MainActor
    func waitForAllTasks() async {
        for task in _tasks.values {
            _ = await task.result
        }
    }

    @MainActor
    var hasTasks: Bool {
        !_tasks.isEmpty
    }

    /// Sends an action to all the services in the pool.
    @MainActor
    public func callAsFunction<A>(action: A) where A: Action {
        if let olderTask = _tasks[action] {
            olderTask.cancel()
        }

        let task = Task { [weak self] in
            let action = AnyAction(action)
            var serviceResults: [(AnyHashable, AnyAction, ServiceResult)] = []
            guard let services = await self?._services else {
                return
            }

            for (_, service) in services {
                do {
                    try await service.pre(action: action)
                }
                catch {
                    if let self = self {
                        await service.error(error, dispatch: self, action: action)
                    }
                    self?._tasks.removeValue(forKey: action)
                    return
                }
            }

            for (name, service) in services {
                let result = await service.send(action: action)

                if result.hasSideEffects {
                    serviceResults.append((name, action, result))
                }
            }

            for (_, service) in services {
                await service.post(action: action)
            }

            if !serviceResults.isEmpty {
                await withTaskGroup(of: (AnyHashable, AnyAction, [Result<Void, Error>]).self) { taskGroup in
                    for (name, action, result) in serviceResults {
                        taskGroup.addTask {
                            (name, action, await result())
                        }
                    }

                    for await (name, action, values) in taskGroup {
                        for value in values {
                            guard let self = self else {
                                continue
                            }

                            let services = await self._services

                            if case let .failure(error) = value {
                                await services[name]?.error(error, dispatch: self, action: action)
                            }
                        }
                    }
                }
            }

            self?._tasks.removeValue(forKey: action)
        }
        _tasks[action] = task
    }
}

#if canImport(SwiftUI)
import SwiftUI

private struct DispatchKey: EnvironmentKey {
    static var defaultValue: Dispatch = ServiceDispatch()
}

public extension EnvironmentValues {
    var dispatch: Dispatch {
        set { self[DispatchKey.self] = newValue }
        get { self[DispatchKey.self] }
    }
}

#endif
