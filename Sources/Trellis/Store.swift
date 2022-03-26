//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Combine
import Foundation

@MainActor
class Store<State> {
    public internal(set) var state: State

    /// Initiates the store with a state.
    public init(initialState: State) {
        state = initialState
    }
}
