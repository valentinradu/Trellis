//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Foundation

public protocol Action {
    associatedtype Name: Hashable
    var name: Name { get }
}

public struct AnyAction: Action {
    public typealias Name = AnyHashable

    internal let action: Any
    public let name: Name
    public init<A: Action>(_ action: A) {
        self.action = action
        name = AnyHashable(action.name)
    }
}

public extension Action {
    func then(other: Self) -> ActionFlow<Self> {
        ActionFlow(actions: [self, other])
    }

    func and(other: Self.Name) -> ActionGroup<Self> {
        ActionGroup(name, other)
    }

    func `in`(group: ActionGroup<Self>) -> Bool {
        group.names.contains(name)
    }
}

public struct ActionFlow<A: Action> {
    internal let actions: [A]
    public func then(_ other: Self) -> Self {
        ActionFlow(actions: actions + other.actions)
    }

    public func then(_ action: A) -> Self {
        ActionFlow(actions: actions + [action])
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
        ActionGroup(names + other.names)
    }

    public func and(_ name: A.Name) -> Self {
        ActionGroup(names + [name])
    }
}

extension ActionGroup: Codable where A.Name: Codable {}
extension ActionFlow: Codable where A: Codable {}
