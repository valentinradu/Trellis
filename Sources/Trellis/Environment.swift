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

protocol EnvironmentConsumer {
    var environmentValues: EnvironmentValues! { get set }
}

protocol EnvironmentProducer {
    var environmentValues: EnvironmentValues! { get set }
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

private struct EnvironmentService<V, W>: Service
    where W: Service
{
    private let _keyPath: KeyPath<EnvironmentValues, V>
    private let _value: V
    private let _wrappedService: W

    init(_ keyPath: KeyPath<EnvironmentValues, V>,
         value: V,
         @ServiceBuilder builder: () -> W)
    {
        _keyPath = keyPath
        _value = value
        _wrappedService = builder()
    }

    var body: some Service {
        _wrappedService
    }
}

public extension Service {
    func environment<V>(_ keyPath: KeyPath<EnvironmentValues, V>,
                        value: V) -> some Service
    {
        EnvironmentService(keyPath, value: value) {
            self
        }
    }
}

extension EnvironmentService: NodeBuilder {
    func transform(environment: inout EnvironmentValues) {
        if let keyPath = _keyPath as? WritableKeyPath<EnvironmentValues, V> {
            environment[keyPath: keyPath] = _value
        }
        else {
            assertionFailure()
        }
    }
}
