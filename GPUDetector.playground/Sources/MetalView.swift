import Foundation
import MetalKit

let shader = """
/*
Math functions are implemented differently in each GPU and drivers.
This will run the same calculation compile time and runtime,
and print the two results in the top-right corner.
It will guess your GPU and OS based on the hashes.

Reciptrocal, sqrt, sin all probably work with constants in a table for a polynom.

If your hardware is unknown or wrong, please comment your hashes and hardware description.

*/

/*
    A metal shading language based version of https://www.shadertoy.com/view/7ssyzr
 */

#include <metal_stdlib>
using namespace metal;

#define UNKNOWN 0
#define WINDOWS 1
#define LINUX 2
#define OSX 3
#define ANDROID 4
#define IOS 5
#define SOFTWARE 6

#define NVIDIA 1
#define AMD 2
#define INTEL 3
#define ADRENO 4
#define MALI 5
#define VIDEOCORE 6
#define APPLE 7

#define GL 1
#define ANGLE 2

#define _space 32

#define _0 48
#define _1 49
#define _2 50
#define _3 51
#define _4 52
#define _5 53
#define _6 54
#define _7 55
#define _8 56
#define _9 57

#define _A 65
#define _B 66
#define _C 67
#define _D 68
#define _E 69
#define _F 70
#define _G 71
#define _H 72
#define _I 73
#define _J 74
#define _K 75
#define _L 76
#define _M 77
#define _N 78
#define _O 79
#define _P 80
#define _Q 81
#define _R 82
#define _S 83
#define _T 84
#define _U 85
#define _V 86
#define _W 87
#define _X 88
#define _Y 89
#define _Z 90


#define _a 97
#define _b 98
#define _c 99
#define _d 100
#define _e 101
#define _f 102
#define _g 103
#define _h 104
#define _i 105
#define _j 106
#define _k 107
#define _l 108
#define _m 109
#define _n 110
#define _o 111
#define _p 112
#define _q 113
#define _r 114
#define _s 115
#define _t 116
#define _u 117
#define _v 118
#define _w 119
#define _x 120
#define _y 121
#define _z 122

#define DYN_ZERO min(0.,time) // forcing runtime calculation
int hardwareHash(float start)
{
    float a=start;
    for(int i=0;i<20;i++)
    {
        a=fract(normalize(float3(a+0.1,6.11,5.22)).x*3.01);
        a+=sin(sqrt(a)*100.3)*0.31;
    }
    return int(fract(fract(abs(a))*256.)*256.*256.);
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    texture2d<float, access::read> font [[texture(1)]],
                    constant float &time [[buffer(0)]],
                    device int *hash_runtime [[buffer(1)]],
                    device int *hash_comptime [[buffer(2)]],
                    uint2 gid [[thread_position_in_grid]]) {

    *hash_runtime = hardwareHash(0.+DYN_ZERO);
    *hash_comptime = hardwareHash(0.);

    output.write(float4(float3(0.0), 1.0), gid);
}
"""

public class MetalView : NSObject, MTKViewDelegate
{
    public var device: MTLDevice! {
        didSet {
            createBuffers()
            registerShaders()
        }
    }

    var queue: MTLCommandQueue!
    var cps: MTLComputePipelineState!

    var vertexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var rps: MTLRenderPipelineState!

    public var runtimeHash: Int64 = 0
    var runtimeHashBuffer: MTLBuffer!
    public var comptimeHash: Int64 = 0
    var comptimeHashBuffer: MTLBuffer!

    var time: Float = 0
    var timeBuffer: MTLBuffer!
    let frameTime: Float = 1.0/60.0


    public init(device: MTLDevice) {
        super.init()

        self.device = device

        configure()
    }

    func configure() {
        createBuffers()
        registerShaders()
    }

    func createBuffers() {

        queue = self.device.makeCommandQueue()

    }

    func registerShaders() {

        do {

            let library = try device.makeLibrary(source: shader, options: nil)

            guard let kernel = library.makeFunction(name: "compute") else {
                fatalError("Couldn't create kernel")
            }

            cps = try device.makeComputePipelineState(function: kernel)

        } catch {
            print(error)
            fatalError(error.localizedDescription)
        }

        timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        runtimeHashBuffer = device.makeBuffer(length: MemoryLayout<Int64>.size, options: [])
        comptimeHashBuffer = device.makeBuffer(length: MemoryLayout<Int64>.size, options: [])

    }

    func update() {
        var bufferPointer = runtimeHashBuffer.contents()
        memcpy(&runtimeHash, bufferPointer, MemoryLayout<Int64>.size)
        bufferPointer = comptimeHashBuffer.contents()
        memcpy(&comptimeHash, bufferPointer, MemoryLayout<Int64>.size)

        print("comptimeHash: \(String(format: "%04X", comptimeHash))\truntimeHash: \(String(format: "%04X", runtimeHash))")
    }

    public
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //
    }

    public
    func draw(in view: MTKView) {
        if let drawable = view.currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, index: 0)
//            commandEncoder.setTexture(fontTexture, index: 1)
            commandEncoder.setBuffer(timeBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(runtimeHashBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(comptimeHashBuffer, offset: 0, index: 2)
            time += frameTime
            let bufferPointer = timeBuffer.contents()
            memcpy(bufferPointer, &time, MemoryLayout<Float>.size)
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()

            update()
        }
    }


}

