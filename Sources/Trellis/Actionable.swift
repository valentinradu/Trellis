//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public protocol Actionable {
    func receive(action: any Action) async throws
}

extension Never: Action {}

public struct EmptyActionable: Actionable {
    public func receive(action: Action) async throws {}
}

public struct AnyActionable: Actionable {
    private let _receive: (Action) async throws -> Void

    public init<O>(_ actionable: O) where O: Actionable {
        _receive = { action in
            try await actionable.receive(action: action)
        }
    }
    
    public func receive<A>(action: A) async throws where A : Action {
        try await _receive(AnyAction(action))
    }
}

@resultBuilder
public enum ActionableBuilder {
    public static func buildBlock() -> EmptyActionable {
        EmptyActionable()
    }

    public static func buildBlock<D>(_ value: D) -> D
        where D: Actionable
    {
        value
    }

    public static func buildIf<D>(_ value: D?) -> D?
        where D: Actionable
    {
        value
    }

    public static func buildEither<T>(first: T) -> T
        where T: Actionable
    {
        first
    }

    public static func buildEither<F>(second: F) -> F
        where F: Actionable
    {
        second
    }

    public static func buildBlock<D0, D1>(_ d0: D0,
                                          _ d1: D1) -> TupleActionable
        where D0: Actionable, D1: Actionable
    {
        TupleActionable((d0, d1))
    }

    public static func buildBlock<D0, D1, D2>(_ d0: D0,
                                              _ d1: D1,
                                              _ d2: D2) -> TupleActionable
        where D0: Actionable, D1: Actionable, D2: Actionable
    {
        TupleActionable((d0, d1, d2))
    }

    public static func buildBlock<D0, D1, D2, D3>(_ d0: D0,
                                                  _ d1: D1,
                                                  _ d2: D2,
                                                  _ d3: D3) -> TupleActionable
        where D0: Actionable, D1: Actionable, D2: Actionable, D3: Actionable
    {
        TupleActionable((d0, d1, d2, d3))
    }

    public static func buildBlock<D0, D1, D2, D3, D4>(_ d0: D0,
                                                      _ d1: D1,
                                                      _ d2: D2,
                                                      _ d3: D3,
                                                      _ d4: D4) -> TupleActionable
        where D0: Actionable, D1: Actionable, D2: Actionable, D3: Actionable, D4: Actionable
    {
        TupleActionable((d0, d1, d2, d3, d4))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5>(_ d0: D0,
                                                          _ d1: D1,
                                                          _ d2: D2,
                                                          _ d3: D3,
                                                          _ d4: D4,
                                                          _ d5: D5) -> TupleActionable
        where D0: Actionable, D1: Actionable, D2: Actionable, D3: Actionable, D4: Actionable, D5: Actionable
    {
        TupleActionable((d0, d1, d2, d3, d4, d5))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5, D6>(_ d0: D0,
                                                              _ d1: D1,
                                                              _ d2: D2,
                                                              _ d3: D3,
                                                              _ d4: D4,
                                                              _ d5: D5,
                                                              _ d6: D6) -> TupleActionable
        where D0: Actionable, D1: Actionable, D2: Actionable, D3: Actionable, D4: Actionable, D5: Actionable, D6: Actionable
    {
        TupleActionable((d0, d1, d2, d3, d4, d5, d6))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5, D6, D7>(_ d0: D0,
                                                                  _ d1: D1,
                                                                  _ d2: D2,
                                                                  _ d3: D3,
                                                                  _ d4: D4,
                                                                  _ d5: D5,
                                                                  _ d6: D6,
                                                                  _ d7: D7) -> TupleActionable
        where D0: Actionable, D1: Actionable, D2: Actionable, D3: Actionable, D4: Actionable, D5: Actionable, D6: Actionable, D7: Actionable
    {
        TupleActionable((d0, d1, d2, d3, d4, d5, d6, d7))
    }
}
