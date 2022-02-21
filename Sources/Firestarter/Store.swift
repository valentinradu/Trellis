//
//  File.swift
//
//
//  Created by Valentin Radu on 17/02/2022.
//

import Foundation
import SwiftUI
import Combine

public protocol StoreKey {
    associatedtype Value
    static var value: Value { get set }
}

public final class StoreRepository {
    fileprivate static var main: StoreRepository = .init()
    fileprivate let objectDidChange: PassthroughSubject<Void, Never> = .init()

    private init() {}

    public subscript<K>(_ key: K.Type) -> K.Value where K: StoreKey {
        get { key.value }
        set {
            key.value = newValue
            objectDidChange.send()
        }
    }
}

private class StoreRepositoryChangeFilter<Value>: ObservableObject where Value: Equatable {
    private var cancellables: Set<AnyCancellable>
    private var value: Value

    init(_ store: StoreRepository,
         keyPath: ReferenceWritableKeyPath<StoreRepository, Value>)
    {
        self.cancellables = []
        self.value = store[keyPath: keyPath]

        store
            .objectDidChange
            .sink { [unowned self] _ in
                if store[keyPath: keyPath] != value {
                    value = store[keyPath: keyPath]
                    objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
}

@propertyWrapper public struct Store<Value: Equatable>: DynamicProperty {
    private var store: StoreRepository
    @StateObject private var filter: StoreRepositoryChangeFilter<Value>
    private let keyPath: ReferenceWritableKeyPath<StoreRepository, Value>

    public init(_ keyPath: ReferenceWritableKeyPath<StoreRepository, Value>) {
        self.store = .main
        self.keyPath = keyPath
        _filter = StateObject(wrappedValue: StoreRepositoryChangeFilter(.main, keyPath: keyPath))
    }

    public var wrappedValue: Value {
        get {
            store[keyPath: keyPath]
        }
        nonmutating set {
            store[keyPath: keyPath] = newValue
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
