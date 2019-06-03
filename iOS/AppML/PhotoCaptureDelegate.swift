//
//  PhotoCaptureDelegate.swift
//  AVCam
//
//  Created by Giulio Zaccaroni on 21/04/2019.
//  Copyright © 2019 Apple. All rights reserved.
//


import AVFoundation
import Photos

class PhotoCaptureProcessor: NSObject {
    
    lazy var context = CIContext()
    
    private let completionHandler: (StereoRecordingFrame?) -> Void
    private var telePhotoData: Data? = nil
    private var wideAngleData: Data? = nil
    private var depthData: CVPixelBuffer? = nil

    init(completionHandler: @escaping (StereoRecordingFrame?) -> Void) {
        self.completionHandler = completionHandler
    }
    
    private func didFinish(result: StereoRecordingFrame?) {
        
        completionHandler(result)
    }
    
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /*
     This extension includes all the delegate callbacks for AVCapturePhotoCaptureDelegate protocol.
     */

    /// - Tag: DidFinishProcessingPhoto
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
        } else {
            guard let imageData = photo.fileDataRepresentation(),
                let deviceType = photo.sourceDeviceType else{
                    return
            }
            
            if deviceType == .builtInTelephotoCamera {

                telePhotoData = imageData
                if let depthData = photo.depthData,
                    CVPixelBufferGetWidth(depthData.depthDataMap) != 0{
                    var convertedDepth: AVDepthData
                    
                    if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
                        convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
                    } else {
                        convertedDepth = depthData
                    }
                    self.depthData = convertedDepth.depthDataMap
                }
            }else if deviceType == .builtInWideAngleCamera{
                wideAngleData = imageData
                if let depthData = photo.depthData,
                    CVPixelBufferGetWidth(depthData.depthDataMap) != 0{
                    var convertedDepth: AVDepthData
                    
                    if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
                        convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
                    } else {
                        convertedDepth = depthData
                    }
                    
                    self.depthData = convertedDepth.depthDataMap
                }
          }
        }

    }
    
    
    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            //print(error)
            didFinish(result: nil)
            return
        }
        
        guard let telephotoData = self.telePhotoData,
              let wideAngleData = self.wideAngleData else {
            didFinish(result: nil)
            return
        }
        depthData?.clamp()
        didFinish(result:
            StereoRecordingFrame(
                depthData: depthData,
                telephoto: telephotoData,
                wideAngle: wideAngleData,
                timeStamp: Date.timeIntervalSinceReferenceDate))
        self.telePhotoData = nil
        self.depthData = nil
        self.wideAngleData = nil
    }
}
struct StereoRecordingFrame: Equatable {
    let depthData: CVPixelBuffer?
    let telephoto: Data
    let wideAngle: Data
    let timeStamp: TimeInterval
}
