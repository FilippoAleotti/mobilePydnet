//
//  CameraStream.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 27/07/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import AVFoundation
import Photos
import Accelerate
import CoreML
import RxSwift
public class CameraStream: NSObject {
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    private let dataOutputQueue = DispatchQueue(label: "data output queue")
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    private var subject: PublishSubject<CVPixelBuffer>?
    
    public func configure() -> Completable{
        return Completable.create { completable in
            return self.sessionQueue.sync {
                return self.configureSession(completable: completable)
            }
        }
    }
    public func start() -> Observable<CVPixelBuffer>{
        let subject = PublishSubject<CVPixelBuffer>()
        sessionQueue.sync {
            self.subject = subject
            session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }
        return subject
    }
    public func stop(){
        sessionQueue.sync {
            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning
            subject?.dispose()
            self.subject = nil
        }
    }
    
    private let videoOutput = AVCaptureVideoDataOutput()
    @objc private dynamic var videoDeviceInput: AVCaptureDeviceInput!
    private func configureSession(completable: ((CompletableEvent) -> ())) -> Cancelable{
        
        session.beginConfiguration()
        
        session.sessionPreset = .hd1920x1080
        
        do {
            
            // default to a wide angle camera.
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else{
                print("Camera video device is unavailable.")
                session.commitConfiguration()
                completable(.error(SessionSetupError.configurationFailed))
                return Disposables.create {}
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
                session.commitConfiguration()
                completable(.error(SessionSetupError.configurationFailed))
                return Disposables.create {}            }
            
        } catch {
            print("Couldn't create video device input: \(error)")
            session.commitConfiguration()
            completable(.error(SessionSetupError.configurationFailed))
            return Disposables.create {}
        }
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        session.addOutput(videoOutput)
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .landscapeLeft
        
        session.commitConfiguration()
        
        completable(.completed)
        return Disposables.create {}
    }
    
}
extension CameraStream: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        subject?.onNext(imageBuffer)
    }
}

public enum SessionSetupError: Error {
    case needAuthorization
    case authorizationDenied
    case configurationFailed
    case multiCamNotSupported
}
