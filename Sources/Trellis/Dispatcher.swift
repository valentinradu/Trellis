//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

/**
The dispatcher 
 */
@MainActor
public class Dispatcher {
    private var _services: [ObjectIdentifier: StatefulReducer] = [:]

    public func register<E, S>(service: Service<E, S>) {
        let id = ObjectIdentifier(service)
        _services[id] = service
    }

    public func unregister<E, S>(service: Service<E, S>) {
        let id = ObjectIdentifier(service)
        _services.removeValue(forKey: id)
    }

    public func send<A>(action: A) where A: Action {
        Task {
            var resolvers: [StatefulReducerResult.Resolver] = []
            for service in _services.values {
                let result = await service.reduce(action: AnyAction(action))

                switch result {
                case .ignore:
                    continue
                case let .resolve(resolver):
                    resolvers.append(resolver)
                }
            }

            for resolver in resolvers {
                do {
                    try await resolver(self)
                } catch {
                    let result = action.transform(error: error)
                    
                    switch result {
                    case .none:
                        break
                    case let .to(action):
                        send(action: action)
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
