//
//  MainViewModel.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 05/09/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import AVFoundation
import RxSwift
import RxRelay
import RxCocoa
import Accelerate

class MainViewModel {
    let fps: Driver<Int>
    let previewImage: Driver<UIImage>
    private(set) var depthPreviewImage: Driver<UIImage> = Driver.empty()
    let isRunning = BehaviorRelay<Bool>(value: false)
    let showDepthPreview = BehaviorRelay<Bool>(value: false)
    let colorFilter = BehaviorRelay<ColorFilter>(value: .none)
    let onShowColorFilterPicker = PublishSubject<Void>()
    let onError: Driver<Error>
    private var cameraStream: CameraStream?

    private let privateOnError = PublishSubject<Error>()
    private let privateFPS = PublishSubject<Int>()
    private let privatePreviewImage = PublishSubject<UIImage>()
    private let privateDepthPreviewImage = PublishSubject<CGImage>()
    private let selectedNeuralNetwork = Pydnet()
    private let inputSize: CGSize = CGSize(width: 640, height: 384)
    private let disposeBag = DisposeBag()

    init() {
        fps = privateFPS.skip(1).asDriver(onErrorDriveWith: Driver.empty())
        previewImage = privatePreviewImage.asDriver(onErrorDriveWith: Driver.empty())
        onError = privateOnError.asDriver(onErrorDriveWith: Driver.empty())
        depthPreviewImage = privateDepthPreviewImage
            .map{ [unowned self] in UIImage(cgImage: self.applyColorMap(toImage: $0)) }
            .asDriver(onErrorDriveWith: Driver.empty())
        

        self.setupCameraController()
        self.configureCameraController()
        
        isRunning.map({ [unowned self] running in
            if running {
                if let error = self.checkPermission() {
                    self.privateOnError.onNext(error)
                }else{
                    self.startCameraController()
                }
            }else{
                self.stopCameraController()
            }
        }).subscribe().disposed(by: disposeBag)
        startFPSRecording()
    }
    // MARK: Logic
    private func checkPermission() -> SessionSetupError?{
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            return nil
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            return .needAuthorization
        default:
            // The user has previously denied access.
            return .authorizationDenied
        }
    }
    private func setupCameraController(){
        stopCameraController()
        cameraStream = CameraStream()
        
    }
    private func configureCameraController(){
        cameraStream?.configure().subscribe { [weak self] completable in
            if case .error(let error) = completable {
                self?.privateOnError.onNext(error)
            }
        }
        .disposed(by: disposeBag)
        
    }
    private func startCameraController() {
        cameraStream?
            .start()
            .subscribe(onNext: { output in
                 self.camera(output: output)
            })
        .disposed(by: disposeBag)
    }
    private func stopCameraController() {
        cameraStream?.stop()
    }
    
    private func camera(output: CVPixelBuffer) {
        var depthImage: CGImage? = nil
        var previewimage: CGImage

        if showDepthPreview.value{
            let resizedPB = output.resize(newSize: inputSize)!
            let start = CFAbsoluteTimeGetCurrent()
            let pixelBuffer = try? selectedNeuralNetwork.prediction(im0__0: resizedPB.pixelBuffer!).mul__0
            let end = CFAbsoluteTimeGetCurrent()
            let timeInterval = end - start
            let fps = 1/timeInterval
            print(fps)
            depthImage = pixelBuffer?.createCGImage()
            previewimage = resizedPB
        }else{
            previewimage = output.createCGImage()!
        }
        privatePreviewImage.onNext(UIImage(cgImage: previewimage))
        if showDepthPreview.value,
            let depthImage = depthImage {
            privateDepthPreviewImage.onNext(depthImage)
        }
        
        self.samplesCollected+=1
    }
    
    // MARK: Depth Converter
    private let photoDepthConverter: ColorMapApplier = MetalColorMapApplier()
    private func applyColorMap(toImage image: CGImage) -> CGImage{
        self.photoDepthConverter.prepare(colorFilter: colorFilter.value)
        return self.photoDepthConverter.render(image: image)!
    }
    // MARK: FPS Logic
    private var samplesCollected: Int = 0

    private var fpsTimer: DispatchSourceTimer?
    
    private func startFPSRecording(){
        fpsTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
        fpsTimer!.setEventHandler(handler: { [unowned self] in
            let samplesCollected = self.samplesCollected
            self.samplesCollected = 0
            self.privateFPS.onNext(Int(round(Double(samplesCollected)/3.0)))
        })
        fpsTimer!.schedule(deadline: .now(), repeating: 3)
        fpsTimer!.resume()
    }
    // MARK: Helpers
    

}
extension CVPixelBuffer {
    fileprivate func resize(newSize: CGSize)-> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
        var scale = newSize.width / ciImage.extent.width
        if(ciImage.extent.height*scale < newSize.height) {
            scale = newSize.height / ciImage.extent.height
        }
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let context = CIContext()
        let retImg = ciImage
            .transformed(by: transform)
            .cropped(to: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        return context.createCGImage(retImg, from: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        
    }
}
