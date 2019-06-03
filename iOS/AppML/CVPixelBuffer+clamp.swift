//
//  CVPixelBuffer+clamp.swift
//  AVCam
//
//  Created by Giulio Zaccaroni on 25/04/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import AVFoundation
import UIKit

extension CVPixelBuffer {
    
    func clamp() {
        
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)
        
        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixel = floatBuffer[y * width + x]
                floatBuffer[y * width + x] = min(1.0, max(pixel, 0.0))
            }
        }
        
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    }
}
