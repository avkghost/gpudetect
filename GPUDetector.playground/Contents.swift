import Cocoa
import Metal
import MetalKit
import PlaygroundSupport

let frame = NSRect(x: 0, y: 0, width: 400, height: 400)

let devices = MTLCopyAllDevices()

let device = devices[0]
//let device = MTLCreateSystemDefaultDevice()!
//for device in devices {

    let delegate = MetalView(device: device)
    let view = MTKView(frame: frame, device: device)
    view.delegate = delegate
    PlaygroundPage.current.liveView = view

    print(device.name)
    print("Is device low power? \(device.isLowPower).")
    print("Is device external? \(device.isRemovable).")
    print("Maximum threads per group: \(device.maxThreadsPerThreadgroup).")
    print("Maximum buffer length: \(Float(device.maxBufferLength) / 1024 / 1024 / 1024) GB.")


//}
