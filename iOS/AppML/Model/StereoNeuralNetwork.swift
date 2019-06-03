//
//  StereoNeuralNetwork.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreVideo
protocol StereoNeuralNetwork: NeuralNetwork {
    func prediction(leftImage: CVPixelBuffer, rightImage: CVPixelBuffer) throws -> CVPixelBuffer
}
