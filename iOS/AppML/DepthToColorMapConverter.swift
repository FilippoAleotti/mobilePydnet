//
//  DepthToColorMapConverter.swift
//  AVCam
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
        self.fillJetTable(size: colors.count)
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
    private func fillJetTable(size: Int) {
        
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

class DepthToColorMapConverter: FilterRenderer {
    
    var description: String = "Depth to Color Map Converter"
    
    var isPrepared = false
    
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    
    private var computePipelineState: MTLComputePipelineState?
    
    private lazy var commandQueue: MTLCommandQueue? = {
        return self.metalDevice.makeCommandQueue()
    }()
    private let colors = 256
    private var colorBuf: MTLBuffer?

    private var textureCache: CVMetalTextureCache!
    private(set) var preparedColorFilter: ColorFilter! = nil
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
    
    func prepare(outputRetainedBufferCountHint: Int, colorFilter: ColorFilter) {
        reset()
        

        if colorFilter != .none {
            var metalTextureCache: CVMetalTextureCache?
            if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
                assertionFailure("Unable to allocate depth converter texture cache")
            } else {
                textureCache = metalTextureCache
            }
            let colorTable = ColorTable(metalDevice: metalDevice, colors: colorFilter.colors)
            colorBuf = colorTable.getColorTable()
        }
        isPrepared = true
        preparedColorFilter = colorFilter
    }
    
    func reset() {
        textureCache = nil
        isPrepared = false
    }
    
    // MARK: - Depth to Grayscale Conversion
    func render(image: CGImage) -> CGImage? {
        if !isPrepared {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }
        if preparedColorFilter == ColorFilter.none {
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
                CVMetalTextureCacheFlush(textureCache!, 0)
                return nil
        }
        
        commandEncoder.label = "Depth to JET"
        commandEncoder.setComputePipelineState(computePipelineState!)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        
        commandEncoder.setBuffer(colorBuf, offset: 0, index: 2)

        // Set up the thread groups.
        let width = computePipelineState!.threadExecutionWidth
        let height = computePipelineState!.maxTotalThreadsPerThreadgroup / width
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
    func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer, textureFormat: MTLPixelFormat) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create a Metal texture from the image buffer
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, textureFormat, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Depth converter failed to create preview texture")
            
            CVMetalTextureCacheFlush(textureCache, 0)
            
            return nil
        }
        
        return texture
    }
    

}
enum ColorFilter: Equatable {
    case none
    case jet
    case plasma
    var colors: [Int] {
        switch self {
        case .none:
            fatalError("Not applicable")
        case .jet:
            return [0x000080, 0x000084, 0x000089, 0x00008D, 0x000092, 0x000096, 0x00009B, 0x00009F, 0x0000A4, 0x0000A8, 0x0000AD, 0x0000B2, 0x0000B6, 0x0000BB, 0x0000BF, 0x0000C4, 0x0000C8, 0x0000CD, 0x0000D1, 0x0000D6, 0x0000DA, 0x0000DF, 0x0000E3, 0x0000E8, 0x0000ED, 0x0000F1, 0x0000F6, 0x0000FA, 0x0000FF, 0x0000FF, 0x0000FF, 0x0000FF, 0x0000FF, 0x0004FF, 0x0008FF, 0x000CFF, 0x0010FF, 0x0014FF, 0x0018FF, 0x001CFF, 0x0020FF, 0x0024FF, 0x0028FF, 0x002CFF, 0x0030FF, 0x0034FF, 0x0038FF, 0x003CFF, 0x0040FF, 0x0044FF, 0x0048FF, 0x004CFF, 0x0050FF, 0x0054FF, 0x0058FF, 0x005CFF, 0x0060FF, 0x0064FF, 0x0068FF, 0x006CFF, 0x0070FF, 0x0074FF, 0x0078FF, 0x007CFF, 0x0080FF, 0x0084FF, 0x0088FF, 0x008CFF, 0x0090FF, 0x0094FF, 0x0098FF, 0x009CFF, 0x00A0FF, 0x00A4FF, 0x00A8FF, 0x00ACFF, 0x00B0FF, 0x00B4FF, 0x00B8FF, 0x00BCFF, 0x00C0FF, 0x00C4FF, 0x00C8FF, 0x00CCFF, 0x00D0FF, 0x00D4FF, 0x00D8FF, 0x00DCFE, 0x00E0FB, 0x00E4F8, 0x02E8F4, 0x06ECF1, 0x09F0EE, 0x0CF4EB, 0x0FF8E7, 0x13FCE4, 0x16FFE1, 0x19FFDE, 0x1CFFDB, 0x1FFFD7, 0x23FFD4, 0x26FFD1, 0x29FFCE, 0x2CFFCA, 0x30FFC7, 0x33FFC4, 0x36FFC1, 0x39FFBE, 0x3CFFBA, 0x40FFB7, 0x43FFB4, 0x46FFB1, 0x49FFAD, 0x4DFFAA, 0x50FFA7, 0x53FFA4, 0x56FFA0, 0x5AFF9D, 0x5DFF9A, 0x60FF97, 0x63FF94, 0x66FF90, 0x6AFF8D, 0x6DFF8A, 0x70FF87, 0x73FF83, 0x77FF80, 0x7AFF7D, 0x7DFF7A, 0x80FF77, 0x83FF73, 0x87FF70, 0x8AFF6D, 0x8DFF6A, 0x90FF66, 0x94FF63, 0x97FF60, 0x9AFF5D, 0x9DFF5A, 0xA0FF56, 0xA4FF53, 0xA7FF50, 0xAAFF4D, 0xADFF49, 0xB1FF46, 0xB4FF43, 0xB7FF40, 0xBAFF3C, 0xBEFF39, 0xC1FF36, 0xC4FF33, 0xC7FF30, 0xCAFF2C, 0xCEFF29, 0xD1FF26, 0xD4FF23, 0xD7FF1F, 0xDBFF1C, 0xDEFF19, 0xE1FF16, 0xE4FF13, 0xE7FF0F, 0xEBFF0C, 0xEEFF09, 0xF1FC06, 0xF4F802, 0xF8F500, 0xFBF100, 0xFEED00, 0xFFEA00, 0xFFE600, 0xFFE200, 0xFFDE00, 0xFFDB00, 0xFFD700, 0xFFD300, 0xFFD000, 0xFFCC00, 0xFFC800, 0xFFC400, 0xFFC100, 0xFFBD00, 0xFFB900, 0xFFB600, 0xFFB200, 0xFFAE00, 0xFFAB00, 0xFFA700, 0xFFA300, 0xFF9F00, 0xFF9C00, 0xFF9800, 0xFF9400, 0xFF9100, 0xFF8D00, 0xFF8900, 0xFF8600, 0xFF8200, 0xFF7E00, 0xFF7A00, 0xFF7700, 0xFF7300, 0xFF6F00, 0xFF6C00, 0xFF6800, 0xFF6400, 0xFF6000, 0xFF5D00, 0xFF5900, 0xFF5500, 0xFF5200, 0xFF4E00, 0xFF4A00, 0xFF4700, 0xFF4300, 0xFF3F00, 0xFF3B00, 0xFF3800, 0xFF3400, 0xFF3000, 0xFF2D00, 0xFF2900, 0xFF2500, 0xFF2200, 0xFF1E00, 0xFF1A00, 0xFF1600, 0xFF1300, 0xFA0F00, 0xF60B00, 0xF10800, 0xED0400, 0xE80000, 0xE40000, 0xDF0000, 0xDA0000, 0xD60000, 0xD10000, 0xCD0000, 0xC80000, 0xC40000, 0xBF0000, 0xBB0000, 0xB60000, 0xB20000, 0xAD0000, 0xA80000, 0xA40000, 0x9F0000, 0x9B0000, 0x960000, 0x920000, 0x8D0000, 0x890000, 0x840000, 0x800000].reversed()
        case .plasma:
            return [0x0D0887, 0x100788, 0x130789, 0x16078A, 0x19068C, 0x1B068D, 0x1D068E, 0x20068F, 0x220690, 0x240691, 0x260591, 0x280592, 0x2A0593, 0x2C0594, 0x2E0595, 0x2F0596, 0x310597, 0x330597, 0x350498, 0x370499, 0x38049A, 0x3A049A, 0x3C049B, 0x3E049C, 0x3F049C, 0x41049D, 0x43039E, 0x44039E, 0x46039F, 0x48039F, 0x4903A0, 0x4B03A1, 0x4C02A1, 0x4E02A2, 0x5002A2, 0x5102A3, 0x5302A3, 0x5502A4, 0x5601A4, 0x5801A4, 0x5901A5, 0x5B01A5, 0x5C01A6, 0x5E01A6, 0x6001A6, 0x6100A7, 0x6300A7, 0x6400A7, 0x6600A7, 0x6700A8, 0x6900A8, 0x6A00A8, 0x6C00A8, 0x6E00A8, 0x6F00A8, 0x7100A8, 0x7201A8, 0x7401A8, 0x7501A8, 0x7701A8, 0x7801A8, 0x7A02A8, 0x7B02A8, 0x7D03A8, 0x7E03A8, 0x8004A8, 0x8104A7, 0x8305A7, 0x8405A7, 0x8606A6, 0x8707A6, 0x8808A6, 0x8A09A5, 0x8B0AA5, 0x8D0BA5, 0x8E0CA4, 0x8F0DA4, 0x910EA3, 0x920FA3, 0x9410A2, 0x9511A1, 0x9613A1, 0x9814A0, 0x99159F, 0x9A169F, 0x9C179E, 0x9D189D, 0x9E199D, 0xA01A9C, 0xA11B9B, 0xA21D9A, 0xA31E9A, 0xA51F99, 0xA62098, 0xA72197, 0xA82296, 0xAA2395, 0xAB2494, 0xAC2694, 0xAD2793, 0xAE2892, 0xB02991, 0xB12A90, 0xB22B8F, 0xB32C8E, 0xB42E8D, 0xB52F8C, 0xB6308B, 0xB7318A, 0xB83289, 0xBA3388, 0xBB3488, 0xBC3587, 0xBD3786, 0xBE3885, 0xBF3984, 0xC03A83, 0xC13B82, 0xC23C81, 0xC33D80, 0xC43E7F, 0xC5407E, 0xC6417D, 0xC7427C, 0xC8437B, 0xC9447A, 0xCA457A, 0xCB4679, 0xCC4778, 0xCC4977, 0xCD4A76, 0xCE4B75, 0xCF4C74, 0xD04D73, 0xD14E72, 0xD24F71, 0xD35171, 0xD45270, 0xD5536F, 0xD5546E, 0xD6556D, 0xD7566C, 0xD8576B, 0xD9586A, 0xDA5A6A, 0xDA5B69, 0xDB5C68, 0xDC5D67, 0xDD5E66, 0xDE5F65, 0xDE6164, 0xDF6263, 0xE06363, 0xE16462, 0xE26561, 0xE26660, 0xE3685F, 0xE4695E, 0xE56A5D, 0xE56B5D, 0xE66C5C, 0xE76E5B, 0xE76F5A, 0xE87059, 0xE97158, 0xE97257, 0xEA7457, 0xEB7556, 0xEB7655, 0xEC7754, 0xED7953, 0xED7A52, 0xEE7B51, 0xEF7C51, 0xEF7E50, 0xF07F4F, 0xF0804E, 0xF1814D, 0xF1834C, 0xF2844B, 0xF3854B, 0xF3874A, 0xF48849, 0xF48948, 0xF58B47, 0xF58C46, 0xF68D45, 0xF68F44, 0xF79044, 0xF79143, 0xF79342, 0xF89441, 0xF89540, 0xF9973F, 0xF9983E, 0xF99A3E, 0xFA9B3D, 0xFA9C3C, 0xFA9E3B, 0xFB9F3A, 0xFBA139, 0xFBA238, 0xFCA338, 0xFCA537, 0xFCA636, 0xFCA835, 0xFCA934, 0xFDAB33, 0xFDAC33, 0xFDAE32, 0xFDAF31, 0xFDB130, 0xFDB22F, 0xFDB42F, 0xFDB52E, 0xFEB72D, 0xFEB82C, 0xFEBA2C, 0xFEBB2B, 0xFEBD2A, 0xFEBE2A, 0xFEC029, 0xFDC229, 0xFDC328, 0xFDC527, 0xFDC627, 0xFDC827, 0xFDCA26, 0xFDCB26, 0xFCCD25, 0xFCCE25, 0xFCD025, 0xFCD225, 0xFBD324, 0xFBD524, 0xFBD724, 0xFAD824, 0xFADA24, 0xF9DC24, 0xF9DD25, 0xF8DF25, 0xF8E125, 0xF7E225, 0xF7E425, 0xF6E626, 0xF6E826, 0xF5E926, 0xF5EB27, 0xF4ED27, 0xF3EE27, 0xF3F027, 0xF2F227, 0xF1F426, 0xF1F525, 0xF0F724, 0xF0F921].reversed()
        }
    }
}
