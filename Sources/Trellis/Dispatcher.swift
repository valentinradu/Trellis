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
    private var _services: [ObjectIdentifier: AnyService] = [:]

    func register<E, S>(service: Service<E, S>) {
        let id = ObjectIdentifier(service)
        _services[id] = AnyService(service)
    }

    func unregister<E, S>(service: Service<E, S>) {
        let id = ObjectIdentifier(service)
        _services.removeValue(forKey: id)
    }

    public func send<A>(action: A) async where A: Action {
        let resolvers = await withTaskGroup(of: ActionSideEffectGroup.self) { taskGroup -> [ActionSideEffectGroup] in
            for service in _services.values {
                if let service = service.base as? Service<Actor, Any> {
                    taskGroup.addTask {
                        await service.reduce(action: action)
                    }
                }
            }

            return await taskGroup.waitForAll()
        }

        Task.detached { [weak self] in
            await withThrowingTaskGroup(of: Void.self) { taskGroup in
                for resolver in resolvers {
                    if let self = self {
                        taskGroup.addTask {
                            try await resolver(self)
                        }
                    }
                    else {
                        taskGroup.cancelAll()
                        return
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
