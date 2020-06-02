//
//  ColorMapApplier.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 08/09/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreGraphics
protocol ColorMapApplier {
    func prepare(colorFilter: ColorFilter)
    func render(image: CGImage) -> CGImage?
}
