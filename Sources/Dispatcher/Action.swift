//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Foundation

public protocol Action {
    associatedtype Name: Equatable
    var name: Name { get }
}

public struct AnyEquatable: Equatable {
    private let value: Any
    private let equals: (Any) -> Bool

    public init<E: Equatable>(_ value: E) {
        self.value = value
        self.equals = { $0 as? E == value }
    }

    public static func ==(lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.equals(rhs.value)
    }
}

public struct AnyAction: Action {
    public typealias Name = AnyEquatable

    private let action: Any
    public let name: Name
    public init<A: Action>(_ action: A) {
        self.action = action
        self.name = AnyEquatable(action.name)
    }
}

public extension Action {
    func then(other: Self) -> ActionFlow<Self> {
        ActionFlow(actions: [self, other])
    }

    func and(other: Self.Name) -> ActionGroup<Self> {
        ActionGroup(self.name, other)
    }

    func `in`(group: ActionGroup<Self>) -> Bool {
        group.names.contains(self.name)
    }
}

public struct ActionFlow<A: Action> {
    fileprivate let actions: [A]
    public func then(_ other: Self) -> Self {
        ActionFlow(actions: self.actions + other.actions)
    }

    public func then(_ action: A) -> Self {
        ActionFlow(actions: self.actions + [action])
    }
}

public struct ActionGroup<A: Action> {
    fileprivate let names: [A.Name]

    public init(_ names: A.Name...) {
        self.names = names
    }

    public init(_ names: [A.Name]) {
        self.names = names
    }

    public func and(_ other: Self) -> Self {
        ActionGroup(self.names + other.names)
    }

    public func and(_ name: A.Name) -> Self {
        ActionGroup(self.names + [name])
    }
}

extension ActionGroup: Codable where A.Name: Codable {}
extension ActionFlow: Codable where A: Codable {}
