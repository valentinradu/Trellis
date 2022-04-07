//
//  File.swift
//
//
//  Created by Valentin Radu on 07/04/2022.
//

import Foundation
import Runtime

class Node {
    private let _environmentValues: EnvironmentValues
    private let _receive: (any Action) async throws -> Void
    private var _children: [Node]

    fileprivate init<S>(_ service: S,
                        environmentValues: EnvironmentValues) throws
        where S: Service
    {
        var mutatingService = service
        let info = try typeInfo(of: S.self)
        for property in info.properties {
            if property.type is EnvironmentValuesContainer {
                try property.set(value: environmentValues, on: &mutatingService)
            }
        }

        _children = []
        _receive = mutatingService.receive
        _environmentValues = environmentValues

        try mutatingService.body.build(in: self)
    }

    func addChild<S>(_ service: S) throws
        where S: Service
    {
        let node = try Node(service,
                            environmentValues: _environmentValues)
        _children.append(node)
    }

    func receive(action: any Action) async throws {
        try await _receive(action)
        for child in _children {
            try await child._receive(action)
        }
    }
}


//public func receive(action: any Action) async throws {
//    let tasks = _items.map { item in
//        Task {
//            try await item.receive(action: action)
//        }
//    }
//
//    switch _concurrencyStrategy {
//    case .concurrent:
//        switch _failureStrategy {
//        case .fail:
//            try await withThrowingTaskGroup(of: Void.self) { group in
//                for task in tasks {
//                    group.addTask {
//                        try await task.value
//                    }
//                }
//
//                try await group.waitForAll()
//            }
//        case let .catch(handler):
//            await withThrowingTaskGroup(of: Void.self) { group in
//                for task in tasks {
//                    group.addTask {
//                        try await task.value
//                    }
//                }
//
//                while let result = await group.nextResult() {
//                    if case let .failure(error) = result {
//                        group.addTask {
//                            try await receive(action: handler(error))
//                        }
//                    }
//                }
//            }
//        }
//    case .serial:
//        switch _failureStrategy {
//        case .fail:
//            for task in tasks {
//                try await task.value
//            }
//        case let .catch(handler):
//            for task in tasks {
//                do {
//                    try await task.value
//                } catch {
//                    try await _dispatch(handler(error))
//                }
//            }
//        }
//    }
//}
