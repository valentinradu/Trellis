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
    static var all: [AnyHashable: EnvironmentValues] = [:]

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
    var environmentValues: MutableRef<EnvironmentValues?> { get }
}

@propertyWrapper
public struct Environment<V>: EnvironmentConsumer {
    let environmentValues: MutableRef<EnvironmentValues?>
    private let _keyPath: KeyPath<EnvironmentValues, V>

    public init(_ keyPath: KeyPath<EnvironmentValues, V>) {
        _keyPath = keyPath
        environmentValues = MutableRef(nil)
    }

    public var wrappedValue: V {
        environmentValues.value![keyPath: _keyPath]
    }
}

private typealias EnvironmentObjects = [ObjectIdentifier: AnyObject]

private struct EnvironmentObjectKey: EnvironmentKey {
    static var defaultValue: EnvironmentObjects = [:]
}

private extension EnvironmentValues {
    var environmentObjects: EnvironmentObjects {
        get { self[EnvironmentObjectKey.self] }
        set { self[EnvironmentObjectKey.self] = newValue }
    }
}

@propertyWrapper
public struct EnvironmentObject<V>: EnvironmentConsumer
    where V: AnyObject
{
    let environmentValues: MutableRef<EnvironmentValues?>

    public init() {
        environmentValues = MutableRef(nil)
    }

    public var wrappedValue: V {
        let objects = environmentValues.value!.environmentObjects
        print(V.self)
        let key = ObjectIdentifier(V.self)
        return objects[key]! as! V
    }
}

private struct EnvironmentTransformer<V, W>: Service
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

    func inject<ID>(environment: EnvironmentValues,
                    from parentId: ID) async throws
        where ID: Identity
    {
        if let keyPath = _keyPath as? WritableKeyPath<EnvironmentValues, V> {
            var environment = environment
            let id = identity(from: parentId)
            let oldValue = environment[keyPath: keyPath]
            environment[keyPath: keyPath] = _transform(oldValue)

            try await body.inject(environment: environment, from: id)
        } else {
            assertionFailure()
        }
    }
}

public extension Service {
    func environment<V>(_ keyPath: KeyPath<EnvironmentValues, V>,
                        value: V) -> some Service
    {
        EnvironmentTransformer(keyPath, transform: { _ in value }) {
            self
        }
    }

    func environmentObject<V>(_ value: V) -> some Service
        where V: AnyObject
    {
        let transform: (EnvironmentObjects) -> EnvironmentObjects = { objects in
            var objects = objects
            let key = ObjectIdentifier(V.self)
            print(type(of: value))
            objects[key] = value
            return objects
        }
        return EnvironmentTransformer(\.environmentObjects, transform: transform) {
            self
        }
    }

    func transformEnvironment<V>(_ keyPath: KeyPath<EnvironmentValues, V>,
                                 transform: @escaping (V) -> V) -> some Service
    {
        EnvironmentTransformer(keyPath, transform: transform) {
            self
        }
    }
}
