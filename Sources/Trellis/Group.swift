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
    public init(@ActionableBuilder _ itemsBuilder: @escaping () -> I) {
        _items = itemsBuilder()
    }

    public func receive(action: I.A) async throws {
        try await _items.receive(action: action)
    }
}
