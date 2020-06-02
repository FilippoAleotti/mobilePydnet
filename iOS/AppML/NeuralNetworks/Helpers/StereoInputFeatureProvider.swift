//
//  StereoInputFeatureProvider.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 07/08/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreML
import CoreVideo
class StereoInputFeatureProvider : MLFeatureProvider {
    private let leftName: String
    private let rightName: String
    private let left: CVPixelBuffer
    private let right: CVPixelBuffer

    var featureNames: Set<String> {
        get {
            return [leftName, rightName]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == rightName) {
            return MLFeatureValue(pixelBuffer: right)
        }
        if (featureName == leftName) {
            return MLFeatureValue(pixelBuffer: left)
        }
        return nil
    }
    
    init(leftName: String, rightName: String, left: CVPixelBuffer, right: CVPixelBuffer) {
        self.leftName = leftName
        self.rightName = rightName
        self.left = left
        self.right = right
    }
}
