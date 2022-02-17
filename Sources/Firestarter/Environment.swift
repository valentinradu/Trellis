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

public struct Environment {
    public subscript<K>(_ key: K.Type) -> K.Value where K: DependencyKey {
        get { key.value }
        set { key.value = newValue }
    }
}
