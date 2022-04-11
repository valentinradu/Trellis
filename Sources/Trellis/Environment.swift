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
    private var _values: [ObjectIdentifier: Any] = [:]
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
public struct Environment<V>: EnvironmentConsumer {
    var environmentValues: EnvironmentValues!
    private let _keyPath: KeyPath<EnvironmentValues, V>

    public init(_ keyPath: KeyPath<EnvironmentValues, V>) {
        _keyPath = keyPath
    }

    public var wrappedValue: V { environmentValues[keyPath: _keyPath] }
}

private struct EnvironmentService<V, W>: Service, EnvironmentTransformer
    where W: Service
{
    private let _keyPath: KeyPath<EnvironmentValues, V>
    private let _transform: (V) -> V
    private let _wrappedService: W

    init(_ keyPath: KeyPath<EnvironmentValues, V>,
         transform: @escaping (V) -> V,
         @ServiceBuilder builder: () -> W)
    {
        _keyPath = keyPath
        _transform = transform
        _wrappedService = builder()
    }

    var body: some Service {
        _wrappedService
    }

    func transformEnvironment(values: EnvironmentValues) -> EnvironmentValues {
        if let keyPath = _keyPath as? WritableKeyPath<EnvironmentValues, V> {
            var values = values
            let oldValue = values[keyPath: keyPath]
            values[keyPath: keyPath] = _transform(oldValue)
            return values
        } else {
            assertionFailure()
            return values
        }
    }
}

public extension Service {
    func environment<V>(_ keyPath: KeyPath<EnvironmentValues, V>,
                        value: V) -> some Service
    {
        EnvironmentService(keyPath, transform: { _ in value }) {
            self
        }
    }

    func transformEnvironment<V>(_ keyPath: KeyPath<EnvironmentValues, V>,
                                 transform: @escaping (V) -> V) -> some Service
    {
        EnvironmentService(keyPath, transform: transform) {
            self
        }
    }
}
