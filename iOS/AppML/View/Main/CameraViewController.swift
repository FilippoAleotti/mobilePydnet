//
//  CameraViewController.swift
//  AVCam
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

class CameraViewController: UIViewController {

    @IBOutlet private var fpsLabel: UILabel!
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet var settingsButton: UIButton!
    @IBOutlet var colorFilterButton: UIButton!
    
    private var depthMap: CIImage? = nil
    private var samplesCollected: Int = 0
    private var previewMode: PreviewMode = .original {
        didSet {
            switch previewMode {
            case .original:
                settingsButton.isHidden = true
                colorFilterButton.isHidden = true
                stopStereo()
            case .depth(neuralNetwork: _ as MonoNeuralNetwork, let filter):
                settingsButton.isHidden = false
                colorFilterButton.isHidden = false
                colorFilterButton.isSelected = filter != .none
                stopStereo()
            case .depth(neuralNetwork: _ as StereoNeuralNetwork, let filter):
                settingsButton.isHidden = false
                colorFilterButton.isHidden = false
                colorFilterButton.isSelected = filter != .none
                startStereo()
            default:
                fatalError("Unexpected neural network")
            }
        }
    }
    let photoDepthConverter = DepthToColorMapConverter()
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Disable UI. Enable the UI later, if and only if the session starts running.
        settingsButton.isHidden = true
        colorFilterButton.isHidden = true
        /*
         Check video authorization status.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
        
        /*
         Setup the capture session.
         In general, it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. We dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.sync {
            self.configureSession()
            DispatchQueue.main.async {
                
                self.startFPSRecording()
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only start the session running if setup succeeded.
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
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
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "AppML", message: "Unable to capture media", preferredStyle: .alert)

                    alertController.addAction(UIAlertAction(title: "Ok",
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    @IBAction func unwindToViewController(segue: UIStoryboardSegue) {
        if let source = segue.source as? NeuralNetworkPickerViewController {
            var colorFilter: ColorFilter = .none
            if case .depth(_, let filter) = previewMode {
                colorFilter = filter
            }
            previewMode = .depth(neuralNetwork: source.selected, filter: colorFilter)
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let dest = segue.destination as? NeuralNetworkPickerViewController {
            if case .depth(let neuralNetwork, _) = previewMode {
                dest.selected = neuralNetwork
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
        super.viewWillDisappear(animated)
    }
    private var fpsTimer: DispatchSourceTimer?
    
    func startFPSRecording(){
        fpsTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
        fpsTimer!.setEventHandler(handler: {
            let samplesCollected = self.samplesCollected
            self.samplesCollected = 0
            
            self.fpsLabel.text = "FPS: \(round(Double(samplesCollected)/2.0))"
            

        })
        fpsTimer!.schedule(deadline: .now(), repeating: 3)
        fpsTimer!.resume()
    }
    override var shouldAutorotate: Bool {
        return false
    }
    @IBAction func showColorFilterPicker(_ sender: Any) {
        let alert = UIAlertController(title: "Filter", message: "", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "JET", style: .default, handler: { [unowned self] _ in
            self.previewMode = self.previewMode.with(filter: .jet)
        }))
        alert.addAction(UIAlertAction(title: "Plasma", style: .default, handler: { [unowned self] _ in
            self.previewMode = self.previewMode.with(filter: .plasma)
        }))
        alert.addAction(UIAlertAction(title: "None", style: .cancel, handler: { [unowned self] _ in
            self.previewMode = self.previewMode.with(filter: .none)
        }))

        self.present(alert, animated: true)
        
    }
    
    
    // MARK: Session Management
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        /*
         We do not create an AVCaptureMovieFileOutput when setting up the session because
         Live Photo is not supported when AVCaptureMovieFileOutput is added to the session.
         */
        session.sessionPreset = .vga640x480
        
        // Add video input.
        do {
            
            // default to a wide angle camera.
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else{
                print("Dual camera video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                try videoDeviceInput.device.lockForConfiguration()
                videoDeviceInput.device.focusMode = .continuousAutoFocus
                videoDeviceInput.device.unlockForConfiguration()
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        // Add photo output.
        /*if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = false
            photoOutput.isDepthDataDeliveryEnabled = false
            #warning("Da modificare in base alle circostanze")
            photoOutput.isDualCameraDualPhotoDeliveryEnabled = false
            
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }*/
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        session.addOutput(videoOutput)
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait

        session.commitConfiguration()
    }
    
    
    // MARK: Device Configuration
    

    @IBOutlet private weak var cameraUnavailableLabel: UILabel!
    
    @IBAction func onChangePreviewType(_ sender: UISegmentedControl) {
        self.fpsLabel.text = "FPS: "
        switch sender.selectedSegmentIndex {
        case 0:
            previewMode = .original
        case 1:
            previewMode = .depth(neuralNetwork: NeuralNetworks.shared.default, filter: .none)
        default:
            break
        }
    }
    
    // MARK: Capturing Photos
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    private var stereoTimer: DispatchSourceTimer?

    private func startStereo(){
        stereoTimer = DispatchSource.makeTimerSource(flags: [], queue: sessionQueue)
        stereoTimer!.setEventHandler(handler: {
            self.capturePhotoInSession(){ frame in
                frame.map{ self.handle(stereoFrame: $0) }
                
            }
        })
        stereoTimer!.schedule(deadline: .now(), repeating: 0.4)
        stereoTimer!.resume()
    }
    private func handle(stereoFrame: StereoRecordingFrame){
        guard case .depth(neuralNetwork: let neuralNetwork as StereoNeuralNetwork) = previewMode else{
            return
        }
        guard let wideAnglePixelBuffer = CIImage(data: stereoFrame.wideAngle)?.pixelBuffer,
            let telephotoPixelBuffer = CIImage(data: stereoFrame.telephoto)?.pixelBuffer else{
                return
        }
        let resizedWideAnglePixelBuffer = resize(buffer: wideAnglePixelBuffer, CGSize(width: 640, height: 448))!
        let resizedTelephotoPixelBuffer = resize(buffer: telephotoPixelBuffer, CGSize(width: 640, height: 448))!
        let cvPixelBuffer = try! neuralNetwork.prediction(leftImage: resizedWideAnglePixelBuffer,
                                                          rightImage: resizedTelephotoPixelBuffer)
        let previewImage = CIImage(cvPixelBuffer: cvPixelBuffer)
        
        let dispImage = UIImage(ciImage: previewImage)
        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = dispImage
        }
    }
    private func stopStereo(){
        guard let videoTimer = self.stereoTimer,
              !videoTimer.isCancelled else{
            return
        }
        self.stereoTimer!.setEventHandler(handler: {})
        self.stereoTimer!.cancel()
        
        self.stereoTimer = nil
    }
    private func capturePhotoInSession(completionHandler: @escaping (StereoRecordingFrame?) -> ()){
        let deviceOrientation = UIDevice.current.orientation
        if let photoOutputConnection = self.photoOutput.connection(with: .video),
            let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) {
            photoOutputConnection.videoOrientation = videoOrientation
        }
        let photoSettings = AVCapturePhotoSettings()
        
        photoSettings.flashMode = .off
        
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.previewPhotoFormat = nil
        photoSettings.embedsDepthDataInPhoto = false
        photoSettings.embedsPortraitEffectsMatteInPhoto = false
        
        photoSettings.isCameraCalibrationDataDeliveryEnabled = false
        photoSettings.isDepthDataFiltered = false
        photoSettings.isAutoDualCameraFusionEnabled = false
        photoSettings.isAutoStillImageStabilizationEnabled = false
        photoSettings.isAutoRedEyeReductionEnabled = false
        photoSettings.isDualCameraDualPhotoDeliveryEnabled = true
        
        photoSettings.isDepthDataDeliveryEnabled = false
        
        let photoCaptureProcessor = PhotoCaptureProcessor(completionHandler: { result in
            // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
            self.sessionQueue.async {
                self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = nil
            }
            completionHandler(result)
        }
        )
        
        // The photo output keeps a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
        self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = photoCaptureProcessor
        self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
    }
    
    enum PreviewMode: Equatable {
        
        case original, depth(neuralNetwork: NeuralNetwork, filter: ColorFilter)
        static func == (lhs: CameraViewController.PreviewMode, rhs: CameraViewController.PreviewMode) -> Bool {
            switch (lhs, rhs) {
            case (.original, .original):
                return true
            case (.depth(let leftNeuralNetwork, _), .depth(let rightNeuralNetwork, _)):
                return leftNeuralNetwork.name == rightNeuralNetwork.name
            default:
                return false
            }
        }
        func with(filter: ColorFilter) -> PreviewMode{
            switch self {
            case .original:
                return .original
            case .depth(let neuralNetwork, _):
                return .depth(neuralNetwork: neuralNetwork, filter: filter)
            }
        }
    }
}
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    fileprivate func resize(buffer: CMSampleBuffer,
                            _ destSize: CGSize)-> CVPixelBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        return resize(buffer: imageBuffer, destSize);
    }
    fileprivate func resize(buffer: CVPixelBuffer,
                            _ destSize: CGSize)-> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        // Get information about the image
        
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CGFloat(CVPixelBufferGetBytesPerRow(buffer))
        let height = CGFloat(CVPixelBufferGetHeight(buffer))
        let width = CGFloat(CVPixelBufferGetWidth(buffer))
        var pixelBuffer: CVPixelBuffer?
        let options = [kCVPixelBufferCGImageCompatibilityKey:true,
                       kCVPixelBufferCGBitmapContextCompatibilityKey:true]
        let topMargin = (height - destSize.height) / CGFloat(2)
        let leftMargin = (width - destSize.width) * CGFloat(2)
        let baseAddressStart = Int(bytesPerRow * topMargin + leftMargin)
        let addressPoint = baseAddress!.assumingMemoryBound(to: UInt8.self)
        let status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, Int(destSize.width), Int(destSize.height), kCVPixelFormatType_32BGRA, &addressPoint[baseAddressStart], Int(bytesPerRow), nil, nil, options as CFDictionary, &pixelBuffer)
        if (status != 0) {
            print(status)
            return nil;
        }
        CVPixelBufferUnlockBaseAddress(buffer,CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer;
    }
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        let previewImage: CIImage
        if case .depth(let neuralNetwork, let colorFilter) = previewMode {
            guard let monoNeuralNetwork = neuralNetwork as? MonoNeuralNetwork else{
                return
            }
            let resizedPixelBuffer = resize(buffer: sampleBuffer, CGSize(width: 448, height: 640))!
            let cvPixelBuffer = try! monoNeuralNetwork.prediction(image: rotate90PixelBuffer(resizedPixelBuffer, factor: 1)!)
            
            previewImage = CIImage(cvPixelBuffer: cvPixelBuffer)
            
            if !self.photoDepthConverter.isPrepared || self.photoDepthConverter.preparedColorFilter != colorFilter {
                self.photoDepthConverter.prepare(outputRetainedBufferCountHint: 3, colorFilter: colorFilter)
            }
            let context = CIContext()

            let displayImage = context.createCGImage(previewImage, from: previewImage.extent)!
            let converted = self.photoDepthConverter.render(image: displayImage)!
            DispatchQueue.main.async { [weak self] in
                let dispImage = UIImage(ciImage: CIImage(cgImage: converted).oriented(.right))
                self?.imageView.image = dispImage
            }
        }else{
            //let resizedPixelBuffer = resize(buffer: sampleBuffer, CGSize(width: 640, height: 448))!
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return  }

            let image = CIImage(cvPixelBuffer: imageBuffer)
            previewImage = image
            let displayImage = UIImage(ciImage: previewImage)
            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = displayImage
            }
        }
        samplesCollected+=1
    }
    public func rotate90PixelBuffer(_ srcPixelBuffer: CVPixelBuffer, factor: UInt8) -> CVPixelBuffer? {
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(srcPixelBuffer, flags) else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, flags) }
        
        guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
            print("Error: could not get pixel buffer base address")
            return nil
        }
        let sourceWidth = CVPixelBufferGetWidth(srcPixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(srcPixelBuffer)
        var destWidth = sourceHeight
        var destHeight = sourceWidth
        var color = UInt8(0)
        
        if factor % 2 == 0 {
            destWidth = sourceWidth
            destHeight = sourceHeight
        }
        
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
        var srcBuffer = vImage_Buffer(data: srcData,
                                      height: vImagePixelCount(sourceHeight),
                                      width: vImagePixelCount(sourceWidth),
                                      rowBytes: srcBytesPerRow)
        
        let destBytesPerRow = destWidth*4
        guard let destData = malloc(destHeight*destBytesPerRow) else {
            print("Error: out of memory")
            return nil
        }
        var destBuffer = vImage_Buffer(data: destData,
                                       height: vImagePixelCount(destHeight),
                                       width: vImagePixelCount(destWidth),
                                       rowBytes: destBytesPerRow)
        
        let error = vImageRotate90_ARGB8888(&srcBuffer, &destBuffer, factor, &color, vImage_Flags(0))
        if error != kvImageNoError {
            print("Error:", error)
            free(destData)
            return nil
        }
        
        let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
            if let ptr = ptr {
                free(UnsafeMutableRawPointer(mutating: ptr))
            }
        }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
        var dstPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(nil, destWidth, destHeight,
                                                  pixelFormat, destData,
                                                  destBytesPerRow, releaseCallback,
                                                  nil, nil, &dstPixelBuffer)
        if status != kCVReturnSuccess {
            print("Error: could not create new pixel buffer")
            free(destData)
            return nil
        }
        return dstPixelBuffer
    }
}

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
    
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}

extension AVCaptureDevice.DiscoverySession {
    var uniqueDevicePositionsCount: Int {
        var uniqueDevicePositions: [AVCaptureDevice.Position] = []
        
        for device in devices {
            if !uniqueDevicePositions.contains(device.position) {
                uniqueDevicePositions.append(device.position)
            }
        }
        
        return uniqueDevicePositions.count
    }
}
