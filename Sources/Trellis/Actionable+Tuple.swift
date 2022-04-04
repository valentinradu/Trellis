//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public struct TupleActionable: Actionable {
    @Environment(\.concurrencyStrategy) private var _concurrencyStrategy
    @Environment(\.failureStrategy) private var _failureStrategy
    @Environment(\.dispatch) private var _dispatch

    let _receive: (AnyAction) async throws -> [Task<Void, Error>]

    init<A0, A1>(_ tuple: (A0, A1))
        where A0: Actionable, A1: Actionable
    {
        _receive = { action in
            var tasks: [Task<Void, Error>] = []

            if let action = action as? A0.A {
                tasks.append(Task {
                    try await tuple.0.receive(action: action)
                })
            }

            if let action = action as? A1.A {
                tasks.append(Task {
                    try await tuple.1.receive(action: action)
                })
            }

            return tasks
        }
    }

    init<A0, A1, A2>(_ tuple: (A0, A1, A2))
        where A0: Actionable, A1: Actionable, A2: Actionable
    {
        _receive = { action in
            var tasks: [Task<Void, Error>] = []

            if let action = action as? A0.A {
                tasks.append(Task {
                    try await tuple.0.receive(action: action)
                })
            }

            if let action = action as? A1.A {
                tasks.append(Task {
                    try await tuple.1.receive(action: action)
                })
            }

            if let action = action as? A2.A {
                tasks.append(Task {
                    try await tuple.2.receive(action: action)
                })
            }

            return tasks
        }
    }

    init<A0, A1, A2, A3>(_ tuple: (A0, A1, A2, A3))
        where A0: Actionable, A1: Actionable, A2: Actionable, A3: Actionable
    {
        _receive = { action in
            var tasks: [Task<Void, Error>] = []

            if let action = action as? A0.A {
                tasks.append(Task {
                    try await tuple.0.receive(action: action)
                })
            }

            if let action = action as? A1.A {
                tasks.append(Task {
                    try await tuple.1.receive(action: action)
                })
            }

            if let action = action as? A2.A {
                tasks.append(Task {
                    try await tuple.2.receive(action: action)
                })
            }

            if let action = action as? A3.A {
                tasks.append(Task {
                    try await tuple.3.receive(action: action)
                })
            }

            return tasks
        }
    }

    init<A0, A1, A2, A3, A4>(_ tuple: (A0, A1, A2, A3, A4))
        where A0: Actionable, A1: Actionable, A2: Actionable, A3: Actionable, A4: Actionable
    {
        _receive = { action in
            var tasks: [Task<Void, Error>] = []

            if let action = action as? A0.A {
                tasks.append(Task {
                    try await tuple.0.receive(action: action)
                })
            }

            if let action = action as? A1.A {
                tasks.append(Task {
                    try await tuple.1.receive(action: action)
                })
            }

            if let action = action as? A2.A {
                tasks.append(Task {
                    try await tuple.2.receive(action: action)
                })
            }

            if let action = action as? A3.A {
                tasks.append(Task {
                    try await tuple.3.receive(action: action)
                })
            }

            if let action = action as? A4.A {
                tasks.append(Task {
                    try await tuple.4.receive(action: action)
                })
            }

            return tasks
        }
    }

    init<A0, A1, A2, A3, A4, A5>(_ tuple: (A0, A1, A2, A3, A4, A5))
        where A0: Actionable, A1: Actionable, A2: Actionable, A3: Actionable,
        A4: Actionable, A5: Actionable
    {
        _receive = { action in
            var tasks: [Task<Void, Error>] = []

            if let action = action as? A0.A {
                tasks.append(Task {
                    try await tuple.0.receive(action: action)
                })
            }

            if let action = action as? A1.A {
                tasks.append(Task {
                    try await tuple.1.receive(action: action)
                })
            }

            if let action = action as? A2.A {
                tasks.append(Task {
                    try await tuple.2.receive(action: action)
                })
            }

            if let action = action as? A3.A {
                tasks.append(Task {
                    try await tuple.3.receive(action: action)
                })
            }

            if let action = action as? A4.A {
                tasks.append(Task {
                    try await tuple.4.receive(action: action)
                })
            }

            if let action = action as? A5.A {
                tasks.append(Task {
                    try await tuple.5.receive(action: action)
                })
            }

            return tasks
        }
    }

    init<A0, A1, A2, A3, A4, A5, A6>(_ tuple: (A0, A1, A2, A3, A4, A5, A6))
        where A0: Actionable, A1: Actionable, A2: Actionable, A3: Actionable,
        A4: Actionable, A5: Actionable, A6: Actionable
    {
        _receive = { action in
            var tasks: [Task<Void, Error>] = []

            if let action = action as? A0.A {
                tasks.append(Task {
                    try await tuple.0.receive(action: action)
                })
            }

            if let action = action as? A1.A {
                tasks.append(Task {
                    try await tuple.1.receive(action: action)
                })
            }

            if let action = action as? A2.A {
                tasks.append(Task {
                    try await tuple.2.receive(action: action)
                })
            }

            if let action = action as? A3.A {
                tasks.append(Task {
                    try await tuple.3.receive(action: action)
                })
            }

            if let action = action as? A4.A {
                tasks.append(Task {
                    try await tuple.4.receive(action: action)
                })
            }

            if let action = action as? A5.A {
                tasks.append(Task {
                    try await tuple.5.receive(action: action)
                })
            }

            if let action = action as? A6.A {
                tasks.append(Task {
                    try await tuple.6.receive(action: action)
                })
            }

            return tasks
        }
    }

    init<A0, A1, A2, A3, A4, A5, A6, A7>(_ tuple: (A0, A1, A2, A3, A4, A5, A6, A7))
        where A0: Actionable, A1: Actionable, A2: Actionable, A3: Actionable,
        A4: Actionable, A5: Actionable, A6: Actionable, A7: Actionable
    {
        _receive = { action in
            var tasks: [Task<Void, Error>] = []

            if let action = action as? A0.A {
                tasks.append(Task {
                    try await tuple.0.receive(action: action)
                })
            }

            if let action = action as? A1.A {
                tasks.append(Task {
                    try await tuple.1.receive(action: action)
                })
            }

            if let action = action as? A2.A {
                tasks.append(Task {
                    try await tuple.2.receive(action: action)
                })
            }

            if let action = action as? A3.A {
                tasks.append(Task {
                    try await tuple.3.receive(action: action)
                })
            }

            if let action = action as? A4.A {
                tasks.append(Task {
                    try await tuple.4.receive(action: action)
                })
            }

            if let action = action as? A5.A {
                tasks.append(Task {
                    try await tuple.5.receive(action: action)
                })
            }

            if let action = action as? A6.A {
                tasks.append(Task {
                    try await tuple.6.receive(action: action)
                })
            }

            if let action = action as? A7.A {
                tasks.append(Task {
                    try await tuple.7.receive(action: action)
                })
            }

            return tasks
        }
    }

    public func receive(action: AnyAction) async throws {
        let tasks = try await _receive(action)

        switch _concurrencyStrategy {
        case .concurrent:
            switch _failureStrategy {
            case .fail:
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for task in tasks {
                        group.addTask {
                            try await task.value
                        }
                    }

                    try await group.waitForAll()
                }
            case let .catch(handler):
                await withThrowingTaskGroup(of: Void.self) { group in
                    for task in tasks {
                        group.addTask {
                            try await task.value
                        }
                    }

                    while let result = await group.nextResult() {
                        if case let .failure(error) = result {
                            group.addTask {
                                try await receive(action: handler(error))
                            }
                        }
                    }
                }
            }
        case .serial:
            switch _failureStrategy {
            case .fail:
                for task in tasks {
                    try await task.value
                }
            case let .catch(handler):
                for task in tasks {
                    do {
                        try await task.value
                    } catch {
                        _dispatch(handler(error))
                    }
                }
            }
        }
    }
}
