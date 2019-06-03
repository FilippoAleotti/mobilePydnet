//
//  NeuralNetwork.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
protocol NeuralNetwork {
    var name: String {get}
}
extension NeuralNetwork {
    var inputType: NeuralNetworkInputType {
        if self is MonoNeuralNetwork {
            return .mono
        }else if self is StereoNeuralNetwork {
            return .stereo
        }else{
            fatalError("Can't use NeuralNetwork")
        }
    }
}
enum NeuralNetworkInputType: CustomStringConvertible {
    case mono, stereo
    var description: String {
        switch self {
        case .mono:
            return "Mono"
        case .stereo:
            return "Stereo"
        }
    }
}
