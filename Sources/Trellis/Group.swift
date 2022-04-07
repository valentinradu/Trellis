//
//  File.swift
//
//
//  Created by Valentin Radu on 04/04/2022.
//

import Foundation

public class Group<I>: Service
    where I: Service
{
    private var _items: I
    public init(@ServiceBuilder _ itemsBuilder: () -> I) {
        _items = itemsBuilder()
    }

    public var body: some Service {
        _items
    }
}

extension Group: NodeBuilder {}
