//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

/**
 The dispatcher
  */
public actor Dispatcher {
    private var _services: [ObjectIdentifier: StatefulReducer] = [:]

    public func register<E, S>(service: Service<E, S>) {
        let id = ObjectIdentifier(service)
        _services[id] = service
    }

    public func unregister<E, S>(service: Service<E, S>) {
        let id = ObjectIdentifier(service)
        _services.removeValue(forKey: id)
    }

    public func send<A>(action: A) async where A: Action {
        let resolvers = await withTaskGroup(of: StatefulReducerResult.self,
                                            returning: [StatefulReducerResult.Resolver].self) { taskGroup in
            for service in _services.values {
                taskGroup.addTask {
                    await service.reduce(action: AnyAction(action))
                }
            }

            var resolvers: [StatefulReducerResult.Resolver] = []
            for await result in taskGroup {
                switch result {
                case .ignore:
                    continue
                case let .resolve(resolver):
                    resolvers.append(resolver)
                }
            }

            return resolvers
        }

        Task.detached { [weak self] in
            await withThrowingTaskGroup(of: Void.self) { taskGroup in
                if let self = self {
                    for resolver in resolvers {
                        taskGroup.addTask {
                            try await resolver(self)
                        }
                    }
                }

                while let result = await taskGroup.nextResult() {
                    switch result {
                    case .success:
                        break
                    case let .failure(error):
                        let actionTransform = action.transform(error: error)

                        switch actionTransform {
                        case .none:
                            break
                        case let .to(action):
                            await self?.send(action: action)
                        }
                    }
                }
            }
        }
    }
}

internal enum StatefulReducerResult {
    typealias Resolver = (Dispatcher) async throws -> Void
    case ignore
    case resolve(Resolver)
}

internal protocol StatefulReducer: AnyObject {
    func reduce(action: AnyAction) async -> StatefulReducerResult
}
