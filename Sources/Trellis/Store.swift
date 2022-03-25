//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Combine
import Foundation

/// The store ensures synchronized access to the state
@MainActor
public class Store<State> {
    public internal(set) var state: State

    /// Initiates the store with a state.
    public init(initialState: State) {
        state = initialState
    }
}
