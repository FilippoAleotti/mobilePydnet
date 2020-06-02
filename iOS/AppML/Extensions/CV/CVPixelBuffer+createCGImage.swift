//
//  CGImage+createPixelBuffer.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 27/07/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreVideo
import VideoToolbox
extension CVPixelBuffer{
    public func createCGImage() -> CGImage? {
      var cgImage: CGImage?
      VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
      return cgImage
    }
}
