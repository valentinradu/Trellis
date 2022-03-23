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
    private var _services: [AnyHashable: Service] = [:]

    func register<ID: Hashable>(_ id: ID, service: Service) {
        _services[id] = service
    }

    func unregister<ID: Hashable>(_ id: ID) {
        _services.removeValue(forKey: id)
    }

    public func send<A>(action: A) async where A: Action {
        let resolvers = await withTaskGroup(of: ServiceResult.self) { taskGroup -> [ServiceResult] in
            for service in _services.values {
                taskGroup.addTask {
                    await service.send(action: action)
                }
            }

            var result: [ServiceResult] = []
            for await sideEffect in taskGroup {
                result.append(sideEffect)
            }
            return result
        }

        Task.detached {
            await withThrowingTaskGroup(of: Void.self) { taskGroup in
                for resolver in resolvers {
                    taskGroup.addTask {
                        await resolver.performSideEffects()
                    }
                }
            }
        }
    }
}
