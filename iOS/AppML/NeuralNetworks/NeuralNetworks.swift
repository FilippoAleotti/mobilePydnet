//
//  NeuralNetworks.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
struct NeuralNetworks {
    private init() {}
    static let shared = NeuralNetworks()
    let list: [NeuralNetwork] = [Pydnet()]
    var `default`: NeuralNetwork{
        return list.first!
    }
}
