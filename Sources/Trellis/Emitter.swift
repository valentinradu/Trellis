//
//  File.swift
//
//
//  Created by Valentin Radu on 08/04/2022.
//

import Foundation

public struct Emitter<I>: Service
    where I: Service
{
    private var _task: Task<Void, Error>?
    private let _stream: AsyncStream<any Action>
    private let _items: I
    private let _consumeOnBootstrap: Bool

    public init(stream: AsyncStream<any Action>, @ServiceBuilder _ itemsBuilder: () -> I) {
        _items = itemsBuilder()
        _stream = stream
        _consumeOnBootstrap = false
        _task = nil
    }

    private init(stream: AsyncStream<any Action>, consumeOnBootstrap: Bool, task: Task<Void, Error>?, items: I) {
        _items = items
        _stream = stream
        _consumeOnBootstrap = consumeOnBootstrap
        _task = task
    }

    public var body: some Service {
        _items
    }

    public func consumeOnBootstrap() -> Self {
        return Emitter(stream: _stream,
                       consumeOnBootstrap: true,
                       task: _task,
                       items: _items)
    }
}
