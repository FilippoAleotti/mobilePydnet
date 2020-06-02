//
//  MonoInputFeatureProvider.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 07/08/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreML
import CoreVideo
class MonoInputFeatureProvider : MLFeatureProvider {
    private let inputName: String
    private let input: CVPixelBuffer

    var featureNames: Set<String> {
        get {
            return [inputName]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == inputName) {
            return MLFeatureValue(pixelBuffer: input)
        }
        return nil
    }
    
    init(inputName: String, input: CVPixelBuffer) {
        self.inputName = inputName
        self.input = input
    }
}
