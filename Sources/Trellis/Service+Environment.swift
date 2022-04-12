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
    static var defaultValue: FailureStrategy = .fail
}

public typealias BootstrapHandler = () async throws -> Void

private struct BootstrapKey: EnvironmentKey {
    static var defaultValue: BootstrapHandler? = nil
}

private struct IdKey: EnvironmentKey {
    static var defaultValue: Int = 0
}

extension EnvironmentValues {
    var concurrencyStrategy: ConcurrencyStrategy {
        get { self[ConcurrencyStrategyKey.self] }
        set { self[ConcurrencyStrategyKey.self] = newValue }
    }

    var failureStrategy: FailureStrategy {
        get { self[FailureStrategyKey.self] }
        set { self[FailureStrategyKey.self] = newValue }
    }

    var bootstrap: BootstrapHandler? {
        get { self[BootstrapKey.self] }
        set { self[BootstrapKey.self] = newValue }
    }

    var id: Int {
        get { self[IdKey.self] }
        set { self[IdKey.self] = newValue }
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

    func bootstrap(_ closure: @escaping BootstrapHandler) -> some Service {
        environment(\.bootstrap, value: closure)
    }
}
