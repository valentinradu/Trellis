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

public struct ConcurrencyStrategyKey: EnvironmentKey {
    public static var defaultValue: ConcurrencyStrategy = .concurrent
}

public typealias FailureStrategyHandler = (Error) -> AnyAction

public enum FailureStrategy {
    case fail
    case `catch`(FailureStrategyHandler)
}

public struct FailureStrategyKey: EnvironmentKey {
    public static var defaultValue: FailureStrategy = .fail
}

public extension EnvironmentValues {
    private(set) var concurrencyStrategy: ConcurrencyStrategy {
        get { self[ConcurrencyStrategyKey.self] }
        set { self[ConcurrencyStrategyKey.self] = newValue }
    }

    private(set) var failureStrategy: FailureStrategy {
        get { self[FailureStrategyKey.self] }
        set { self[FailureStrategyKey.self] = newValue }
    }
}

public extension Actionable {
    func `catch`(_ closure: FailureStrategyHandler?) -> some Actionable {
        environment(\.failureStrategy,
                    value: closure != nil ? .catch(closure!) : .fail)
    }

    func concurrent() -> some Actionable {
        environment(\.concurrencyStrategy, value: .concurrent)
    }

    func serial() -> some Actionable {
        environment(\.concurrencyStrategy, value: .serial)
    }
}
