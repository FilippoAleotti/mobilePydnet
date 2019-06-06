/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal compute shader that translates depth values to color map RGB values.
*/

#include <metal_stdlib>
using namespace metal;

struct BGRAPixel {
    uchar b;
    uchar g;
    uchar r;
    uchar a;
};

// Compute kernel
kernel void depthToColorMap(texture2d<float, access::read>  inputTexture      [[ texture(0) ]],
                       texture2d<float, access::write> outputTexture     [[ texture(1) ]],
                       constant BGRAPixel *colorTable [[ buffer(2) ]],
                       uint2 gid [[ thread_position_in_grid ]])
{
	// Ensure we don't read or write outside of the texture
	if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
		return;
	}
	
	float depth = inputTexture.read(gid).x;
    float scale_factor = 10.5;
    depth = depth * scale_factor * 255;
    if(depth > 255){
        depth = 255;
    }
    if(depth <0){
        depth = 0;
    }
    
    BGRAPixel outputColor = colorTable[(int) (depth)];
    outputTexture.write(float4(outputColor.b / 255.0, outputColor.g / 255.0, outputColor.r / 255.0, 1.0), gid);

    //outputTexture.write(float4(outputColor.r / 255.0, outputColor.g / 255.0, outputColor.b / 255.0, 1.0), gid);
}
