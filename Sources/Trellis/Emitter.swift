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
    @Environment(\.id) private var _id
    private var _task: Task<Void, Error>?
    private let _stream: AsyncStream<any Action>
    private let _items: I
    private let _consume: Bool

    public init(stream: AsyncStream<any Action>,
                @ServiceBuilder _ itemsBuilder: () -> I) {
        _items = itemsBuilder()
        _stream = stream
        _consume = false
        _task = nil
    }

    private init(stream: AsyncStream<any Action>,
                 consume: Bool,
                 task: Task<Void, Error>?,
                 items: I) {
        _items = items
        _stream = stream
        _consume = consume
        _task = task
    }

    public var body: some Service {
        _items
            .bootstrap {
                let task = Task {
                    for await action in _stream {
                        try await send(action: action,
                                       from: _id)
                    }
                }
                
                if _consume {
                    try await task.value
                }
            }
    }

    public func consume() -> Self {
        return Emitter(stream: _stream,
                       consume: true,
                       task: _task,
                       items: _items)
    }
}
