//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public protocol EnvironmentKey {
    associatedtype V
    static var defaultValue: V { get }
}

public struct EnvironmentValues {
    fileprivate static var main: EnvironmentValues = .init(_values: [:])
    private var _values: [ObjectIdentifier: Any]
    public subscript<K>(_ key: K.Type) -> K.V where K: EnvironmentKey {
        get {
            _values[ObjectIdentifier(key)] as? K.V ?? key.defaultValue
        }
        set {
            _values[ObjectIdentifier(key)] = newValue
        }
    }
}

@propertyWrapper
public struct Environment<V> {
    public let wrappedValue: V
    public init(_ keyPath: KeyPath<EnvironmentValues, V>) {
        wrappedValue = EnvironmentValues.main[keyPath: keyPath]
    }
}

private struct EnvironmentActionable<W, V>: Actionable where W: Actionable {
    private let _keyPath: KeyPath<EnvironmentValues, V>
    private let _value: V
    private let _wrappedActionable: W

    init(_ keyPath: KeyPath<EnvironmentValues, V>,
         value: V,
         @ActionableBuilder builder: () -> W)
    {
        _keyPath = keyPath
        _value = value
        _wrappedActionable = builder()
    }

    func receive<A>(action: A) async throws where A: Action {
//        let oldValue = EnvironmentValues.main[keyPath: _keyPath]
//        EnvironmentValues.main[keyPath: _keyPath] = _value
        try await _wrappedActionable.receive(action: action)
//        EnvironmentValues.main[keyPath: _keyPath] = oldValue
    }
}

public extension Actionable {
    func environment<V>(_ keyPath: KeyPath<EnvironmentValues, V>,
                        value: V) -> some Actionable
    {
        EnvironmentActionable(keyPath, value: value) {
            self
        }
    }
}
