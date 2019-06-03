//
//  Pydnet.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreVideo
struct Pydnet: MonoNeuralNetwork {
    let name: String = "Pydnet"
    private let model = OptimizedPydnet()
    func prediction(image: CVPixelBuffer) throws -> CVPixelBuffer {
        return try model.prediction(im0__0: image).PSD__resize__ResizeBilinear__0
    }
}
