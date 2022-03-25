//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Combine
import Foundation

/// The store ensures synchronized access to the state
public actor Store<State> {
    public private(set) var state: State

    /// Initiates the store with a state.
    public init(initialState: State) {
        state = initialState
    }

    func update<T>(_ closure: (inout State) -> T) -> T {
        return closure(&state)
    }
}
