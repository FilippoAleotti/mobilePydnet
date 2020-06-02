//
//  NeuralNetworkRepository.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreML
import Model
struct NeuralNetworkRepository {
    static var shared = NeuralNetworkRepository()
    
    private(set) var list: [NeuralNetwork]
    var `default`: NeuralNetwork{
        return list.first!
    }
    
    private let networksPath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("networks", isDirectory: true)
    
    private init() {
        if(!FileManager.default.fileExists(atPath: networksPath.absoluteString)){
            try! FileManager.default.createDirectory(at: networksPath, withIntermediateDirectories: true)
        }
        self.list = []
        loadNeuralNetworks()
    }
    private mutating func loadNeuralNetworks(){
        list.removeAll()
        list.append(try! NeuralNetwork(name: "Pydnet", model: OptimizedPydnet().model, disparity: true, scaleFactor: 10.5))
        list.append(try! NeuralNetwork(name: "Pydnet Stereo", model: PydnetS().model, disparity: false, scaleFactor: 1))
        list.append(try! NeuralNetwork(name: "Quantized Pydnet",model: PydnetQuantized().model, disparity: true, scaleFactor: 10.5))
        let files = (try? FileManager.default.contentsOfDirectory(at: networksPath, includingPropertiesForKeys: nil, options: [])) ?? []
        for file in files{
            do {
                list.append(try NeuralNetwork(url: file))
            }catch {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    mutating func add(network: URL) throws{
        if(network.pathExtension != "mlmodel"){
            throw NetworkCompilationError.wrongFileFormat
        }
        let compiledURL = try MLModel.compileModel(at: network)
        let network = try NeuralNetwork(url: compiledURL)
        var file = networksPath.appendingPathComponent(network.name).appendingPathExtension("mlmodelc")
        if(FileManager.default.fileExists(atPath: file.absoluteString)){
            var fileNameFound = false
            var index = 1
            repeat{
                file = networksPath.appendingPathComponent(network.name + "_\(index)").appendingPathExtension("mlmodelc")
                if(!FileManager.default.fileExists(atPath: file.absoluteString)){
                    fileNameFound = true
                }else{
                    index+=1;
                }
            }while(!fileNameFound)
        }
        try FileManager.default.copyItem(at: compiledURL, to: file)
        list.append(try NeuralNetwork(url: file))
    }
    func get(name: String) -> NeuralNetwork? {
        return list.first(where: { $0.name == name})
    }
    func getAll() -> [NeuralNetwork]{
        return list
    }
    mutating func delete(network: NeuralNetwork) throws {
        guard let url = network.url else{
            throw NetworkDeletionError.nonDeletable
        }
        try FileManager.default.removeItem(at: url)
        list.removeAll(where: {$0 == network})
    }
}
enum NetworkCompilationError: Error {
    case wrongFileFormat
    var localizedDescription: String {
        switch self {
        case .wrongFileFormat:
            return "Wrong file format"
        }
    }
}
enum NetworkDeletionError: Error {
    case nonDeletable
    var localizedDescription: String {
        switch self {
        case .nonDeletable:
            return "This network is not deletable"
        }
    }
}
