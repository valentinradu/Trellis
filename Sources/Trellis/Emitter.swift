//
//  File.swift
//
//
//  Created by Valentin Radu on 08/04/2022.
//

import Foundation

private struct Emitter<I>: Service
    where I: Service
{
    @Environment(\.id) private var _id
    private var _task: Task<Void, Error>?
    private let _stream: AsyncStream<any Action>
    private let _items: I
    private let _consumeAtBootstrap: Bool

    init(stream: AsyncStream<any Action>,
         consumeAtBootstrap: Bool,
         @ServiceBuilder _ itemsBuilder: () -> I)
    {
        _items = itemsBuilder()
        _stream = stream
        _consumeAtBootstrap = consumeAtBootstrap
        _task = nil
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

                if _consumeAtBootstrap {
                    try await task.value
                }
            }
    }
}

public extension Service {
    func emit(upstream stream: AsyncStream<any Action>,
              consumeAtBootstrap: Bool = false) -> some Service
    {
        Emitter(stream: stream,
                consumeAtBootstrap: consumeAtBootstrap) {
            self
        }
    }
}
