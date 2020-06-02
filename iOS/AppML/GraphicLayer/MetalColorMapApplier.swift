//
//  DepthToColorMapConverter.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 21/04/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import CoreMedia
import CoreVideo
import MetalKit

struct BGRAPixel {
    var blue: UInt8 = 0
    var green: UInt8 = 0
    var red: UInt8 = 0
    var alpha: UInt8 = 0
}

class ColorTable: NSObject {
    private var tableBuf: MTLBuffer?
    
    required init (metalDevice: MTLDevice, colors: [Int]) {
        self.tableBuf = metalDevice.makeBuffer(length: MemoryLayout<BGRAPixel>.size * colors.count, options: .storageModeShared)
        self.colors = colors
        super.init()
        self.fillTable(size: colors.count)
    }
    
    deinit {
    }
    private func set(table: UnsafeMutablePointer<BGRAPixel>, index: Int, rgb: Int){
        table[index].alpha = (UInt8)(255)
        table[index].red = (UInt8)((rgb >> 16) & 0xFF)
        table[index].green = (UInt8)((rgb >> 8) & 0xFF)
        table[index].blue = (UInt8)(rgb & 0xFF)
        
    }
    private let colors: [Int]
    private func fillTable(size: Int) {
        
        let table = tableBuf?.contents().bindMemory(to: BGRAPixel.self, capacity: size)
        // Get pixel info
        for idx in 0..<size {
            
            set(table: table!, index: idx, rgb: colors[idx])
        }
    }
    
    func getColorTable() -> MTLBuffer {
        return tableBuf!
    }
}

class MetalColorMapApplier: ColorMapApplier {
    var isPrepared = false
    
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    
    private var computePipelineState: MTLComputePipelineState?

    private lazy var commandQueue: MTLCommandQueue? = {
        return self.metalDevice.makeCommandQueue()
    }()
    private let colors = 256
    private var colorBuf: MTLBuffer?
    
    private(set) var preparedColorFilter: ColorFilter? = nil
    private let bytesPerPixel = 8
    
    
    required init() {
        let defaultLibrary = metalDevice.makeDefaultLibrary()!
        let kernelFunction = defaultLibrary.makeFunction(name: "depthToColorMap")
        do {
            computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
        } catch {
            fatalError("Unable to create depth converter pipeline state. (\(error))")
        }
        
    }
    
    func prepare(colorFilter: ColorFilter) {
        guard preparedColorFilter != colorFilter else {
            return
        }
        reset()
        
        
        if colorFilter != .none {
            let colorTable = ColorTable(metalDevice: metalDevice, colors: colorFilter.colors)
            colorBuf = colorTable.getColorTable()
        }
        isPrepared = true
        preparedColorFilter = colorFilter
    }
    
    func reset() {
        colorBuf = nil
        isPrepared = false
    }
    
    // MARK: - Depth to colormap Conversion
    func render(image: CGImage) -> CGImage? {
        if !isPrepared {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }
        let preparedColorFilter = self.preparedColorFilter!
        guard preparedColorFilter != .none else {
            return image
        }
        guard let outputTexture = texture(pixelFormat: .bgra8Unorm, width: image.width, height: image.height),
            let inputTexture = texture(from: image) else {
                return nil
        }
        
        // Set up command queue, buffer, and encoder
        guard let commandQueue = commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                print("Failed to create Metal command queue")
                return nil
        }

        commandEncoder.label = "Depth to Colormap"
        let computePipelineState = self.computePipelineState!
        
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)

        if preparedColorFilter != .none {
            commandEncoder.setBuffer(colorBuf, offset: 0, index: 3)
        }

        // Set up the thread groups.
        let width = computePipelineState.threadExecutionWidth
        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let threadgroupsPerGrid = MTLSize(width: (inputTexture.width + width - 1) / width,
                                          height: (inputTexture.height + height - 1) / height,
                                          depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        
        return cgImage(from: outputTexture)
    }
    private func cgImage(from texture: MTLTexture) -> CGImage? {
        
        // The total number of bytes of the texture
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        
        // The number of bytes for each image row
        let bytesPerRow = texture.width * bytesPerPixel
        
        // An empty buffer that will contain the image
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        // Gets the bytes from the texture
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        // Creates an image context
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &src, width: texture.width, height: texture.height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        // Creates the image from the graphics context
        let dstImage = context?.makeImage()
        
        // Creates the final UIImage
        return dstImage
    }
    private func texture(from image: CGImage) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: self.metalDevice)
        do {
            let textureOut = try textureLoader.newTexture(cgImage: image)
            return textureOut
        }
        catch {
            return nil
        }
    }
    private func texture(pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        return self.metalDevice.makeTexture(descriptor: textureDescriptor)
    }
    
    
}
enum ColorFilter: Equatable {
    case none
    case magma
    var colors: [Int] {
        switch self {
        case .none:
            fatalError("Not applicable")
        case .magma:
            return [0x000003,0x000004,0x000006,0x010007,0x010109,0x01010B,0x02020D,0x02020F,0x030311,0x040313,0x040415,0x050417,0x060519,0x07051B,0x08061D,0x09071F,0x0A0722,0x0B0824,0x0C0926,0x0D0A28,0x0E0A2A,0x0F0B2C,0x100C2F,0x110C31,0x120D33,0x140D35,0x150E38,0x160E3A,0x170F3C,0x180F3F,0x1A1041,0x1B1044,0x1C1046,0x1E1049,0x1F114B,0x20114D,0x221150,0x231152,0x251155,0x261157,0x281159,0x2A115C,0x2B115E,0x2D1060,0x2F1062,0x301065,0x321067,0x341068,0x350F6A,0x370F6C,0x390F6E,0x3B0F6F,0x3C0F71,0x3E0F72,0x400F73,0x420F74,0x430F75,0x450F76,0x470F77,0x481078,0x4A1079,0x4B1079,0x4D117A,0x4F117B,0x50127B,0x52127C,0x53137C,0x55137D,0x57147D,0x58157E,0x5A157E,0x5B167E,0x5D177E,0x5E177F,0x60187F,0x61187F,0x63197F,0x651A80,0x661A80,0x681B80,0x691C80,0x6B1C80,0x6C1D80,0x6E1E81,0x6F1E81,0x711F81,0x731F81,0x742081,0x762181,0x772181,0x792281,0x7A2281,0x7C2381,0x7E2481,0x7F2481,0x812581,0x822581,0x842681,0x852681,0x872781,0x892881,0x8A2881,0x8C2980,0x8D2980,0x8F2A80,0x912A80,0x922B80,0x942B80,0x952C80,0x972C7F,0x992D7F,0x9A2D7F,0x9C2E7F,0x9E2E7E,0x9F2F7E,0xA12F7E,0xA3307E,0xA4307D,0xA6317D,0xA7317D,0xA9327C,0xAB337C,0xAC337B,0xAE347B,0xB0347B,0xB1357A,0xB3357A,0xB53679,0xB63679,0xB83778,0xB93778,0xBB3877,0xBD3977,0xBE3976,0xC03A75,0xC23A75,0xC33B74,0xC53C74,0xC63C73,0xC83D72,0xCA3E72,0xCB3E71,0xCD3F70,0xCE4070,0xD0416F,0xD1426E,0xD3426D,0xD4436D,0xD6446C,0xD7456B,0xD9466A,0xDA4769,0xDC4869,0xDD4968,0xDE4A67,0xE04B66,0xE14C66,0xE24D65,0xE44E64,0xE55063,0xE65162,0xE75262,0xE85461,0xEA5560,0xEB5660,0xEC585F,0xED595F,0xEE5B5E,0xEE5D5D,0xEF5E5D,0xF0605D,0xF1615C,0xF2635C,0xF3655C,0xF3675B,0xF4685B,0xF56A5B,0xF56C5B,0xF66E5B,0xF6705B,0xF7715B,0xF7735C,0xF8755C,0xF8775C,0xF9795C,0xF97B5D,0xF97D5D,0xFA7F5E,0xFA805E,0xFA825F,0xFB8460,0xFB8660,0xFB8861,0xFB8A62,0xFC8C63,0xFC8E63,0xFC9064,0xFC9265,0xFC9366,0xFD9567,0xFD9768,0xFD9969,0xFD9B6A,0xFD9D6B,0xFD9F6C,0xFDA16E,0xFDA26F,0xFDA470,0xFEA671,0xFEA873,0xFEAA74,0xFEAC75,0xFEAE76,0xFEAF78,0xFEB179,0xFEB37B,0xFEB57C,0xFEB77D,0xFEB97F,0xFEBB80,0xFEBC82,0xFEBE83,0xFEC085,0xFEC286,0xFEC488,0xFEC689,0xFEC78B,0xFEC98D,0xFECB8E,0xFDCD90,0xFDCF92,0xFDD193,0xFDD295,0xFDD497,0xFDD698,0xFDD89A,0xFDDA9C,0xFDDC9D,0xFDDD9F,0xFDDFA1,0xFDE1A3,0xFCE3A5,0xFCE5A6,0xFCE6A8,0xFCE8AA,0xFCEAAC,0xFCECAE,0xFCEEB0,0xFCF0B1,0xFCF1B3,0xFCF3B5,0xFCF5B7,0xFBF7B9,0xFBF9BB,0xFBFABD,0xFBFCBF]
        }
    }
}
