//
//  File.swift
//
//
//  Created by Valentin Radu on 24/03/2022.
//

import Combine
import SwiftUI

//private class StoreWatcher<S>: ObservableObject where S: Equatable {
//    private let _store: Store<S>
//    private var cancellables: Set<AnyCancellable>
//
//    init(store: Store<S>) {
//        self.store = store
//        store.stateWillChange
//            .sink { [weak self] in
//                self?.objectWillChange.send()
//            }
//            .store(in: &cancellables)
//    }
//}
//
//@propertyWrapper
//public struct StoreState<S>: DynamicProperty where S: Equatable {
//    public var wrappedValue: S {
//        _watcher.store.state
//    }
//
//    @StateObject private var _watcher: StoreWatcher<S>
//
//    init(_ keyPath: KeyPath<EnvironmentValues, Store<S>>) {
//        let env = Environment(keyPath)
//        let watcher = StoreWatcher(store: env.wrappedValue)
//        __watcher = StateObject(wrappedValue: watcher)
//    }
//}
