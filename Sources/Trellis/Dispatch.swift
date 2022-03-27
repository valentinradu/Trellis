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
    private var _services: [AnyHashable: Service] = [:]
    @MainActor private var _tasks: [AnyHashable: Task<Void, Never>] = [:]

    func register<ID: Hashable>(_ id: ID, service: Service) {
        _services[id] = service
    }

    func unregister<ID: Hashable>(_ id: ID) {
        _services.removeValue(forKey: id)
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
        let key = AnyHashable(action)
        if let olderTask = _tasks[key] {
            olderTask.cancel()
        }

        let task = Task { [weak self] in
            var results: [ServiceResult] = []
            if let services = await self?._services.values {
                for service in services {
                    let result = await service.send(action: action)

                    if result.hasSideEffects {
                        results.append(result)
                    }
                }
            }

            if !results.isEmpty {
                await withTaskGroup(of: Void.self) { taskGroup in
                    for result in results {
                        taskGroup.addTask {
                            await result()
                        }
                    }
                }
            }

            self?._tasks.removeValue(forKey: key)
        }
        _tasks[key] = task
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
