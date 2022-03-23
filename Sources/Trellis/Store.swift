//
//  File.swift
//
//
//  Created by Valentin Radu on 23/03/2022.
//

import Foundation

public actor Store<State> {
    public private(set) var state: State

    public init(_ state: State) {
        self.state = state
    }

    func update<T>(_ closure: (inout State) -> T) -> T {
        return closure(&state)
    }
}
