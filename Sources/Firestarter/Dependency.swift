//
//  File.swift
//
//
//  Created by Valentin Radu on 17/02/2022.
//

import Foundation

public protocol DependencyKey {
    associatedtype Value
    static var value: Value { get set }
}

public struct DependencyRepository {
    public static var main: DependencyRepository = .init()

    private init() {}

    public subscript<K>(_ key: K.Type) -> K.Value where K: DependencyKey {
        get { key.value }
        set { key.value = newValue }
    }
}

@propertyWrapper public struct Dependency<Value> {
    private let key: KeyPath<DependencyRepository, Value>

    public init(_ key: KeyPath<DependencyRepository, Value>) {
        self.key = key
    }

    public var wrappedValue: Value { DependencyRepository.main[keyPath: key] }
}
