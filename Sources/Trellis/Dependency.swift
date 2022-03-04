//
//  File.swift
//
//
//  Created by Valentin Radu on 17/02/2022.
//

import Combine
import Foundation

public protocol DependencyKey {
    associatedtype Value
    static var value: Value { get set }
}

public final class DependencyRepository {
    fileprivate static var main: DependencyRepository = .init()

    private init() {}

    public subscript<K>(_ key: K.Type) -> K.Value where K: DependencyKey {
        get { key.value }
        set { key.value = newValue }
    }
}

@propertyWrapper public struct Dependency<Value> {
    private let keyPath: ReferenceWritableKeyPath<DependencyRepository, Value>

    public init(_ keyPath: ReferenceWritableKeyPath<DependencyRepository, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        get {
            DependencyRepository.main[keyPath: keyPath]
        }
        set {
            DependencyRepository.main[keyPath: keyPath] = newValue
        }
    }
}
