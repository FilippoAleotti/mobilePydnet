//
//  MainViewController.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 21/04/2019.
//  Copyright © 2019 Apple. All rights reserved.
//


import UIKit
import AVFoundation
import Photos
import MobileCoreServices
import Accelerate
import CoreML
import VideoToolbox
import RxSwift

class MainViewController: UIViewController {
    
    @IBOutlet var typeSegmentedControl: UISegmentedControl!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var fpsLabel: UILabel!
    @IBOutlet private var previewView: UIImageView!
    @IBOutlet private var depthPreviewView: UIImageView!
    @IBOutlet private var settingsButton: UIButton!
    @IBOutlet private var colorFilterButton: UIButton!
    private var isVisible: Bool = false
    private let applicationViewModel = MainViewModel()
    private let disposeBag = DisposeBag()

    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        typeSegmentedControl.rx.selectedSegmentIndex.map{ $0 == 1 }.bind(to: applicationViewModel.showDepthPreview).disposed(by: disposeBag)
        applicationViewModel.showDepthPreview.map{ $0 ? 1 : 0}.bind(to: typeSegmentedControl.rx.selectedSegmentIndex).disposed(by: disposeBag)
        applicationViewModel.showDepthPreview.map{ !$0 }.bind(to: colorFilterButton.rx.isHidden).disposed(by: disposeBag)
        applicationViewModel.showDepthPreview.map{ !$0 }.bind(to: depthPreviewView.rx.isHidden).disposed(by: disposeBag)
        applicationViewModel.depthPreviewImage.drive(depthPreviewView.rx.image).disposed(by: disposeBag)
        applicationViewModel.previewImage.drive(previewView.rx.image).disposed(by: disposeBag)
        applicationViewModel.fps.map{ "FPS: \($0)"}.drive(fpsLabel.rx.text).disposed(by: disposeBag)
        applicationViewModel.colorFilter.map{ $0 != .none}.bind(to: colorFilterButton.rx.isSelected).disposed(by: disposeBag)
        applicationViewModel.onError.drive(onNext: { error in
            switch error {
            case SessionSetupError.needAuthorization:
                self.requestAccessToVideoStream()
            case SessionSetupError.authorizationDenied:
                self.askToChangePrivacySettings()
            case SessionSetupError.configurationFailed:
                self.show(error: "Unable to capture media")
            case SessionSetupError.multiCamNotSupported:
                self.show(error: "Multi cam is not supported")
            default:
                self.show(error: error.localizedDescription)
            }
            }).disposed(by: disposeBag)
        applicationViewModel.onShowColorFilterPicker.map{ [unowned self] in self.showColorFilterPicker() }.subscribe().disposed(by: disposeBag)
        colorFilterButton.rx.tap.bind(to: applicationViewModel.onShowColorFilterPicker).disposed(by: disposeBag)

    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.applicationViewModel.isRunning.accept(true)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.applicationViewModel.isRunning.accept(false)
    }
    private func show(error: String){
            let alertController = UIAlertController(title: "AppML", message: error, preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: "Ok",
                                                    style: .cancel,
                                                    handler: nil))
            
            self.present(alertController, animated: true, completion: nil)
    }
    private func requestAccessToVideoStream(){
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
            if !granted {
                self.askToChangePrivacySettings()
            }else{
                self.applicationViewModel.isRunning.accept(true)
            }
        })
    }
    private func askToChangePrivacySettings(){
        let changePrivacySetting = "AppML doesn't have permission to use the camera, please change privacy settings"
        let alertController = UIAlertController(title: "AppML", message: changePrivacySetting, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Ok",
                                                style: .cancel,
                                                handler: nil))
        
        alertController.addAction(UIAlertAction(title: "Settings",
                                                style: .`default`,
                                                handler: { _ in
                                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                              options: [:],
                                                                              completionHandler: nil)
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    override var shouldAutorotate: Bool {
        return false
    }
    @IBAction func showColorFilterPicker() {
        let alert = UIAlertController(title: "Colormap", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Magma", style: .default, handler: { [unowned self] _ in
            self.applicationViewModel.colorFilter.accept(.magma)
        }))
        alert.addAction(UIAlertAction(title: "None", style: .cancel, handler: { [unowned self] _ in
            self.applicationViewModel.colorFilter.accept(.none)
        }))
        
        self.present(alert, animated: true)
        
    }
}
