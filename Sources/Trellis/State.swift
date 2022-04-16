//
//  File.swift
//
//
//  Created by Valentin Radu on 15/04/2022.
//

import Foundation

protocol StateConsumer {
    var id: MutableRef<(AnyHashable, AnyHashable)?> { get }
}

private enum StateStorage {
    static var all: [AnyHashable: [AnyHashable: Any]] = [:]
}

@propertyWrapper
public struct State<V>: StateConsumer {
    var id: MutableRef<(AnyHashable, AnyHashable)?>

    public init() {
        id = MutableRef(nil)
    }

    public var wrappedValue: V {
        get {
            guard let id = id.value,
                  let storage = StateStorage.all[id.0]
            else {
                fatalError()
            }
            return storage[id.1] as! V
        }
        set {
            guard let id = id.value,
                  let storage = StateStorage.all[id.0]
            else {
                fatalError()
            }

            if storage[id.1] == nil {
                StateStorage.all[id.0]![id.1] = newValue
            }
        }
    }
}
