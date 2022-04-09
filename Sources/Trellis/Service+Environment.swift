//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public enum ConcurrencyStrategy {
    case concurrent
    case serial
}

public typealias FailureStrategyHandler = (Error) -> any Action

private struct ConcurrencyStrategyKey: EnvironmentKey {
    public static var defaultValue: ConcurrencyStrategy = .concurrent
}

enum FailureStrategy {
    case fail
    case `catch`(FailureStrategyHandler)
}

private struct FailureStrategyKey: EnvironmentKey {
    public static var defaultValue: FailureStrategy = .fail
}

extension EnvironmentValues {
    private(set) var concurrencyStrategy: ConcurrencyStrategy {
        get { self[ConcurrencyStrategyKey.self] }
        set { self[ConcurrencyStrategyKey.self] = newValue }
    }

    private(set) var failureStrategy: FailureStrategy {
        get { self[FailureStrategyKey.self] }
        set { self[FailureStrategyKey.self] = newValue }
    }
}

public extension Service {
    func transformError(_ closure: FailureStrategyHandler?) -> some Service {
        environment(\.failureStrategy,
                    value: closure != nil ? .catch(closure!) : .fail)
    }

    func concurrent() -> some Service {
        environment(\.concurrencyStrategy, value: .concurrent)
    }

    func serial() -> some Service {
        environment(\.concurrencyStrategy, value: .serial)
    }
}
