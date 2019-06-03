//
//  MonoNeuralNetwork.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreVideo
protocol MonoNeuralNetwork: NeuralNetwork {
    func prediction(image: CVPixelBuffer) throws -> CVPixelBuffer
    
}
