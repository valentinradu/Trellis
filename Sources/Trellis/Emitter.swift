//
//  File.swift
//
//
//  Created by Valentin Radu on 08/04/2022.
//

import Foundation

public final class Emitter<I>: Service
    where I: Service
{
    private var _task: Task<Void, Error>!
    private var _items: I

    public init<A>(stream: AsyncStream<A>, @ServiceBuilder _ itemsBuilder: () -> I)
        where A: Action
    {
        _items = itemsBuilder()
        _task = Task { [weak self] in
            for await action in stream {
                try Task.checkCancellation()
                try await self?.receive(action: action)
            }
        }
    }

    public var body: some Service {
        _items
    }

    deinit {
        _task.cancel()
    }
}
