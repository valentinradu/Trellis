//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public class Group<I>: Actionable
    where I: Actionable
{
    private var _items: I
    public init(@ActionableBuilder _ itemsBuilder: () -> I) {
        _items = itemsBuilder()
    }

    public func receive<A>(action: A) async throws where A: Action {
        try await _items.receive(action: action)
    }
}
