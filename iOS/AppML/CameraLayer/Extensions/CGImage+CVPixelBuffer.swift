//
//  CGImage+CVPixelBuffer.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 07/08/2019.
//  Copyright © 2019 Apple. All rights reserved.
//


import CoreGraphics
import CoreImage
import VideoToolbox
extension CGImage {
  /**
    Resizes the image to width x height and converts it to an RGB CVPixelBuffer.
  */
    public var pixelBuffer: CVPixelBuffer? {
    return pixelBuffer(width: width, height: height,
                       pixelFormatType: kCVPixelFormatType_32ARGB,
                       colorSpace: CGColorSpaceCreateDeviceRGB(),
                       alphaInfo: .noneSkipFirst)
    }
  public func pixelBuffer(width: Int, height: Int,
                          orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
    return pixelBuffer(width: width, height: height,
                       pixelFormatType: kCVPixelFormatType_32ARGB,
                       colorSpace: CGColorSpaceCreateDeviceRGB(),
                       alphaInfo: .noneSkipFirst)
  }

  func pixelBuffer(width: Int, height: Int, pixelFormatType: OSType,
                   colorSpace: CGColorSpace, alphaInfo: CGImageAlphaInfo) -> CVPixelBuffer? {

    var maybePixelBuffer: CVPixelBuffer?
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     width,
                                     height,
                                     pixelFormatType,
                                     attrs as CFDictionary,
                                     &maybePixelBuffer)

    guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
      return nil
    }

    let flags = CVPixelBufferLockFlags(rawValue: 0)
    guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
      return nil
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }

    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                  space: colorSpace,
                                  bitmapInfo: alphaInfo.rawValue)
    else {
      return nil
    }

    context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixelBuffer
  }
}
