//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Foundation

public protocol Action {
    associatedtype Name
    var name: Name { get }
}

public extension Action {
    func then(other: Self) -> ActionFlow<Self> {
        ActionFlow(actions: [self, other])
    }

    func and(other: Self.Name) -> ActionNameGroup<Self> {
        ActionNameGroup(self.name, other)
    }

    func depends(on other: Self.Name) -> ActionNameGraph<Self> {
        ActionNameGraph(dependencies: [other])
    }

    func depends(on others: ActionNameGroup<Self>) -> ActionNameGraph<Self> {
        ActionNameGraph(dependencies: others.names)
    }

    func depends(on others: Self.Name...) -> ActionNameGraph<Self> {
        ActionNameGraph(dependencies: others)
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

public struct ActionNameGroup<A: Action> {
    fileprivate let names: [A.Name]

    public init(_ names: A.Name...) {
        self.names = names
    }

    public init(_ names: [A.Name]) {
        self.names = names
    }

    public func and(_ other: Self) -> Self {
        ActionNameGroup(self.names + other.names)
    }

    public func and(_ name: A.Name) -> Self {
        ActionNameGroup(self.names + [name])
    }

    public func depends(on other: A.Name) -> ActionNameGraph<A> {
        ActionNameGraph(dependencies: [other])
    }

    public func depends(on others: ActionNameGroup<A>) -> ActionNameGraph<A> {
        ActionNameGraph(dependencies: others.names)
    }

    public func depends(on others: A.Name...) -> ActionNameGraph<A> {
        ActionNameGraph(dependencies: others)
    }
}

public struct ActionNameGraph<A: Action> {
    fileprivate let dependencies: [A.Name]

    public func depends(on other: A.Name) -> Self {
        ActionNameGraph(dependencies: self.dependencies + [other])
    }

    public func depends(on others: ActionNameGraph) -> Self {
        ActionNameGraph(dependencies: self.dependencies + others.dependencies)
    }

    public func depends(on others: ActionNameGroup<A>) -> Self {
        ActionNameGraph(dependencies: self.dependencies + others.names)
    }

    public func depends(on others: A.Name...) -> Self {
        ActionNameGraph(dependencies: self.dependencies + others)
    }
}

extension ActionFlow: Codable where A: Codable {}
