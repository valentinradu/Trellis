//
//  File.swift
//
//
//  Created by Valentin Radu on 15/04/2022.
//

import Foundation

private typealias AnyFactoryProvider = () -> Any

private struct FactoryProvidersKey: EnvironmentKey {
    static var defaultValue: [ObjectIdentifier: AnyFactoryProvider] = [:]
}

private extension EnvironmentValues {
    var factoryProviders: [ObjectIdentifier: AnyFactoryProvider] {
        get { self[FactoryProvidersKey.self] }
        set { self[FactoryProvidersKey.self] = newValue }
    }
}

public struct Factory<S, V>: Service where S: Service {
    @Environment(\.factoryProviders) private var _providers
    public typealias Builder = (V) -> S
    private typealias Provider = (V.Type) -> V
    private let _itemsBuilder: Builder
    public init(@ServiceBuilder _ itemsBuilder: @escaping Builder) {
        _itemsBuilder = itemsBuilder
    }

    public var body: some Service {
        if let value = value {
            _itemsBuilder(value)
        }
    }

    private var value: V? {
        _providers[ObjectIdentifier(V.self)]?() as? V
    }
}

public typealias FactoryProvider<V> = (V.Type) -> V

public extension Service {
    func provide<V>(_ type: V.Type,
                    callback: @escaping FactoryProvider<V>) -> some Service {
        transformEnvironment(\.factoryProviders) {
            var result = $0
            result[ObjectIdentifier(type)] = {
                callback(type)
            }
            return result
        }
    }
}
