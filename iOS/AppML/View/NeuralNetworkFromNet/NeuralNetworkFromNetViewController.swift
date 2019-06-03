//
//  NeuralNetworkFromNetViewController.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 31/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import CoreML
class NeuralNetworkFromNetViewController: UITableViewController {
    @IBOutlet private var urlTextField: UITextField!
    @IBOutlet private var loadingInfoTableViewCell: UITableViewCell!
    @IBOutlet private var progressView: UIProgressView!
    @IBOutlet private var progressLabel: UILabel!
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                progressView.progress = 0.0
                loadingInfoTableViewCell.isHidden = false
                progressLabel.text = "Loading..."
            }else{
                loadingInfoTableViewCell.isHidden = true
            }
        }
    }
    @IBAction func add(_ sender: Any) {
        guard !isLoading else{
            return
        }
        isLoading = true
    }
    
    @IBAction func undo(_ sender: Any) {
        guard !isLoading else{
            return
        }
    }
    
}
// Business logic
extension NeuralNetworkFromNetViewController {
    enum NeuralNetworkFromNetError: Error {
        case generic
    }
    fileprivate func download(url: URL, progress: @escaping (Double) -> (), completioHandler: @escaping (Result<Data, Error>) -> ()){
        var observation: NSKeyValueObservation?
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            observation?.invalidate()
            guard let data = data else{
                completioHandler(Result.failure(error ?? NeuralNetworkFromNetError.generic))
                return
            }
            completioHandler(Result.success(data))
        }
        // Don't forget to invalidate the observation when you don't need it anymore.
        observation = task.progress.observe(\.fractionCompleted) { currentProgress, _ in
            progress(currentProgress.fractionCompleted)
        }
        
        task.resume()
    }
}
