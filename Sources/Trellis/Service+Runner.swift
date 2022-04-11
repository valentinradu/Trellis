//
//  File.swift
//
//
//  Created by Valentin Radu on 11/04/2022.
//

import Foundation

public typealias TaskRunnerHandler = () async throws -> Void

private struct TaskService<I>: Service, TaskRunner
    where I: Service
{
    private var _items: I
    private var _closure: TaskRunnerHandler
    init(task: @escaping TaskRunnerHandler, @ServiceBuilder _ itemsBuilder: () -> I) {
        _items = itemsBuilder()
        _closure = task
    }

    var body: some Service {
        _items
    }

    func run() async throws {
        try await _closure()
    }
}

public extension Service {
//    func task(_ closure: @escaping TaskRunnerHandler) -> some Service {
//        TaskService(task: closure) {
//            self
//        }
//    }
}
