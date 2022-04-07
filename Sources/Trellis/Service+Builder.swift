//
//  File.swift
//  
//
//  Created by Valentin Radu on 06/04/2022.
//

import Foundation

@resultBuilder
public enum ServiceBuilder {
    public static func buildBlock() -> EmptyService {
        EmptyService()
    }
    
    public static func buildBlock(_ value: Never) -> Never {}

    public static func buildBlock<A>(_ value: A) -> some Service
        where A: Service
    {
        value
    }

    public static func buildIf<A>(_ value: A?) -> A?
        where A: Service
    {
        value
    }

    public static func buildEither<A>(first: A) -> some Service
        where A: Service
    {
        first
    }

    public static func buildEither<A>(second: A) -> some Service
        where A: Service
    {
        second
    }

    public static func buildBlock<D0, D1>(_ d0: D0,
                                          _ d1: D1) -> _TupleService
        where D0: Service, D1: Service
    {
        _TupleService((d0, d1))
    }

    public static func buildBlock<D0, D1, D2>(_ d0: D0,
                                              _ d1: D1,
                                              _ d2: D2) -> _TupleService
        where D0: Service, D1: Service, D2: Service
    {
        _TupleService((d0, d1, d2))
    }

    public static func buildBlock<D0, D1, D2, D3>(_ d0: D0,
                                                  _ d1: D1,
                                                  _ d2: D2,
                                                  _ d3: D3) -> _TupleService
        where D0: Service, D1: Service, D2: Service, D3: Service
    {
        _TupleService((d0, d1, d2, d3))
    }

    public static func buildBlock<D0, D1, D2, D3, D4>(_ d0: D0,
                                                      _ d1: D1,
                                                      _ d2: D2,
                                                      _ d3: D3,
                                                      _ d4: D4) -> _TupleService
        where D0: Service, D1: Service, D2: Service, D3: Service, D4: Service
    {
        _TupleService((d0, d1, d2, d3, d4))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5>(_ d0: D0,
                                                          _ d1: D1,
                                                          _ d2: D2,
                                                          _ d3: D3,
                                                          _ d4: D4,
                                                          _ d5: D5) -> _TupleService
        where D0: Service, D1: Service, D2: Service, D3: Service, D4: Service, D5: Service
    {
        _TupleService((d0, d1, d2, d3, d4, d5))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5, D6>(_ d0: D0,
                                                              _ d1: D1,
                                                              _ d2: D2,
                                                              _ d3: D3,
                                                              _ d4: D4,
                                                              _ d5: D5,
                                                              _ d6: D6) -> _TupleService
        where D0: Service, D1: Service, D2: Service, D3: Service, D4: Service, D5: Service, D6: Service
    {
        _TupleService((d0, d1, d2, d3, d4, d5, d6))
    }

    public static func buildBlock<D0, D1, D2, D3, D4, D5, D6, D7>(_ d0: D0,
                                                                  _ d1: D1,
                                                                  _ d2: D2,
                                                                  _ d3: D3,
                                                                  _ d4: D4,
                                                                  _ d5: D5,
                                                                  _ d6: D6,
                                                                  _ d7: D7) -> _TupleService
        where D0: Service, D1: Service, D2: Service, D3: Service, D4: Service, D5: Service, D6: Service, D7: Service
    {
        _TupleService((d0, d1, d2, d3, d4, d5, d6, d7))
    }
}
