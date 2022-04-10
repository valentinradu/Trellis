//
//  File.swift
//
//
//  Created by Valentin Radu on 08/04/2022.
//

import Foundation

public struct Emitter<I>: Service, CustomBootstrap
    where I: Service
{
    private var _task: Task<Void, Error>?
    private var _stream: AsyncStream<any Action>
    private var _items: I

    public init(stream: AsyncStream<any Action>, @ServiceBuilder _ itemsBuilder: () -> I) {
        _items = itemsBuilder()
        _stream = stream
    }

    public var body: some Service {
        _items
    }

    public mutating func bootstrap() async throws {
        let stream = _stream
        let receive = _items.receive
        _task = Task {
            for await action in stream {
                try Task.checkCancellation()
                try await receive(action)
            }
        }
    }
}
