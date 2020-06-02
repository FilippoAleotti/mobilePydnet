//
//  StereoCameraOutput.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 07/08/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreVideo
struct StereoCameraOutput: CameraOutput {
    let leftFrame: CVPixelBuffer
    let rightFrame: CVPixelBuffer
}
