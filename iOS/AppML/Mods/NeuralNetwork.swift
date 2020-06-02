//
//  FileNeuralNetwork.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 06/08/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreML
class NeuralNetwork: Equatable {
    let name: String
    private let model: MLModel
    let type: StreamType
    let inputSize: CGSize
    let outputs: [String: CGSize]
    var desiredOutput: String {
        didSet {
            guard oldValue != desiredOutput else{
                return
            }
            var networkSettings = self.networkSettings
            networkSettings[defaultsKeys.networkDesiredOutput] = desiredOutput
            self.networkSettings = networkSettings
        }
    }
    private(set) var url: URL? = nil
    var scaleFactor: Float {
        didSet {
            guard oldValue != scaleFactor else{
                return
            }
            var networkSettings = self.networkSettings
            networkSettings[defaultsKeys.networkScaleFactor] = scaleFactor
            self.networkSettings = networkSettings
        }
    }
    var disparity: Bool {
        didSet {
            guard oldValue != disparity else{
                return
            }
            var networkSettings = self.networkSettings
            networkSettings[defaultsKeys.networkIsDisparity] = disparity
            self.networkSettings = networkSettings
        }
    }
    private let input: String?
    private let leftInput: String?
    private let rightInput: String?
    convenience init(url: URL, disparity: Bool = true, scaleFactor: Float = 1.0) throws{
        let model = try MLModel(contentsOf: url)
        try self.init(name: (url.lastPathComponent as NSString).deletingPathExtension, model: model, disparity: disparity, scaleFactor: scaleFactor)
        self.url = url
    }
    init(name: String, model: MLModel, disparity: Bool = true, scaleFactor: Float = 10.5) throws{
        self.model = model
        guard !model.modelDescription.inputDescriptionsByName.isEmpty else{
            throw NeuralNetworkError.inputNotFound
        }
        guard !model.modelDescription.outputDescriptionsByName.isEmpty else{
            throw NeuralNetworkError.outputNotFound
        }
        self.name = name
        let inputDescriptions = model.modelDescription.inputDescriptionsByName.filter{ $0.value.type == .image}
        
        if(inputDescriptions.count == 1){
            type = .mono
            let input = inputDescriptions.first!
            self.leftInput = nil
            self.rightInput = nil
            self.input = input.key
            let inputIC = input.value.imageConstraint!
            inputSize = CGSize(width: inputIC.pixelsWide, height: inputIC.pixelsHigh)
        }else if(inputDescriptions.count == 2){
            type = .stereo
            let keys = inputDescriptions.keys.sorted()
            let leftInput = inputDescriptions.first(where: { $0.key.localizedCaseInsensitiveContains("left")}) ?? inputDescriptions.first(where: {$0.key == keys.first})!
            let rightInput = inputDescriptions.first(where: { $0.key.localizedCaseInsensitiveContains("right")}) ?? inputDescriptions.first(where: {$0.key == keys.last})!
            self.leftInput = leftInput.key
            self.rightInput = rightInput.key
            self.input = nil
            let leftInputIC = leftInput.value.imageConstraint!
            let rightInputIC = rightInput.value.imageConstraint!
            guard leftInputIC.pixelsHigh == rightInputIC.pixelsHigh,
                  leftInputIC.pixelsWide == rightInputIC.pixelsWide else{
                throw NeuralNetworkError.differentInputsSize
            }
            guard leftInputIC.pixelFormatType == rightInputIC.pixelFormatType else{
                throw NeuralNetworkError.differentInputsPixelFormatType
            }
            inputSize = CGSize(width: leftInputIC.pixelsWide, height: leftInputIC.pixelsHigh)
        }else{
            throw NeuralNetworkError.invalidInput
        }
        let outputDescriptions = model.modelDescription.outputDescriptionsByName.filter{ $0.value.type == .image}
        guard !outputDescriptions.isEmpty else{
            throw NeuralNetworkError.invalidOutput
        }
        var outputs: [String: CGSize] = [:]
        for outputDescription in outputDescriptions {
            guard let imageConstraint = outputDescription.value.imageConstraint else{
                throw NeuralNetworkError.invalidOutput
            }
            outputs[outputDescription.key] = CGSize(width: imageConstraint.pixelsWide, height: imageConstraint.pixelsHigh)
        }
        self.outputs = outputs
        self.disparity = disparity
        self.scaleFactor = scaleFactor
        self.desiredOutput = outputs.keys.sorted().first!
        loadCustomSettings()
    }
    func refresh(){
        loadCustomSettings()
    }
    func prediction(outputName: String, image: CVPixelBuffer) throws -> CVPixelBuffer {
        guard outputs.keys.contains(outputName) else{
            throw NeuralNetworkError.outputNotFound
        }
        guard type == .mono else{
            throw NeuralNetworkError.unsupportedMode
        }
        let featureProvider = MonoInputFeatureProvider(inputName: input!, input: image)
        let outputFeatureProvider = try model.prediction(from: featureProvider)
        guard let output = outputFeatureProvider.featureValue(for: outputName)?.imageBufferValue else{
            throw NeuralNetworkError.invalidOutput
        }
        return output
        
    }
    func prediction(outputName: String, left: CVPixelBuffer, right: CVPixelBuffer) throws -> CVPixelBuffer {
        guard outputs.keys.contains(outputName) else{
            throw NeuralNetworkError.outputNotFound
        }
        guard type == .stereo else{
            throw NeuralNetworkError.unsupportedMode
        }
        let featureProvider = StereoInputFeatureProvider(leftName: leftInput!, rightName: rightInput!, left: left, right: right)
        let outputFeatureProvider = try model.prediction(from: featureProvider)
        guard let output = outputFeatureProvider.featureValue(for: outputName)?.imageBufferValue else{
            throw NeuralNetworkError.invalidOutput
        }
        return output
    }
    struct ImageFeature {
        let size: CGSize
        let name: String
    }
    static func ==(lhs: NeuralNetwork, rhs: NeuralNetwork) -> Bool{
        return lhs.url == rhs.url &&
            lhs.name == rhs.name
            && lhs.type == rhs.type
            && lhs.inputSize == rhs.inputSize
            && lhs.input == rhs.input
            && lhs.outputs == rhs.outputs
    }

}
// MARK: Customization options
extension NeuralNetwork {
    private var userDefaultID: String {
        let id: String
        if let nonOptURL = url {
            id = nonOptURL.lastPathComponent
        }else{
            id = name
        }
        return id
    }
    private var networkSettings: [String: Any] {
        get {
            guard var settings = UserDefaults.standard.dictionary(forKey: defaultsKeys.networksSettings) else{
                let newSettings: [String: [String: Any]] = [userDefaultID:[:]]
                UserDefaults.standard.set(newSettings, forKey: defaultsKeys.networksSettings)
                return [:]
            }
            guard let networkSettings = settings[userDefaultID] as? [String: Any] else{
                settings[userDefaultID] = [:]
                UserDefaults.standard.set(settings, forKey: defaultsKeys.networksSettings)
                return [:]
            }
            return networkSettings
        }
        set {
            var settings = UserDefaults.standard.dictionary(forKey: defaultsKeys.networksSettings) ?? [:]
            
            settings[userDefaultID] = newValue
            UserDefaults.standard.set(settings, forKey: defaultsKeys.networksSettings)
        }
    }
    private func loadCustomSettings(){
        let networkSetting = self.networkSettings
        if let disparity = networkSetting[defaultsKeys.networkIsDisparity] as? Bool {
            self.disparity = disparity
        }
        if let scaleFactor = networkSetting[defaultsKeys.networkScaleFactor] as? Float {
            self.scaleFactor = scaleFactor
        }
        if let desiredOutput = networkSetting[defaultsKeys.networkDesiredOutput] as? String {
            self.desiredOutput = desiredOutput
        }
    }
    struct defaultsKeys {
        static let networksSettings = "networksSettings"
        static let networkIsDisparity = "isDisparity"
        static let networkDesiredOutput = "output"
        static let networkScaleFactor = "scaleFactor"
    }
}
