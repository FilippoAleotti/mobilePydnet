//
//  NeuralNetwork.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreVideo
import CoreImage

extension NeuralNetwork {

    func prediction(outputName: String, image: CVPixelBuffer) throws -> CGImage {
        let context = CIContext()
        let cvPixelBuffer: CVPixelBuffer = try prediction(outputName: outputName, image: image)
        let previewImage = CIImage(cvPixelBuffer: cvPixelBuffer)
        return context.createCGImage(previewImage, from: previewImage.extent)!
    }
    func prediction(outputName: String, left: CVPixelBuffer, right: CVPixelBuffer) throws -> CGImage {
        let context = CIContext()
        let cvPixelBuffer: CVPixelBuffer = try prediction(outputName: outputName, left: left, right: right)
        let previewImage = CIImage(cvPixelBuffer: cvPixelBuffer)
        return context.createCGImage(previewImage, from: previewImage.extent)!
    }

    enum NeuralNetworkError: Error {
        case tooManyInputs
        case differentInputsSize
        case differentInputsPixelFormatType
        case inputNotFound
        case outputNotFound
        case invalidInput
        case invalidOutput
        case unsupportedMode
        var localizedDescription: String {
            switch self {
            case .tooManyInputs:
                return "Too many inputs"
            case .differentInputsSize:
                return "Inputs have different size"
            case .differentInputsPixelFormatType:
                return "Inputs have different pixel format type"
            case .inputNotFound:
                return "Input not found"
            case .outputNotFound:
                return "Output not found"
            case .invalidInput:
                return "Input is not valid"
            case .invalidOutput:
                return "Output is not valid"
            case .unsupportedMode:
                return "This mode is not supported on this network"
            }
        }
    }
}
