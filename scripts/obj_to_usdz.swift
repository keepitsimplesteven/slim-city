// Converts an OBJ (with its MTL + Textures beside it) to a USDZ.
// Build tooling only; not part of the app.
//   swiftc scripts/obj_to_usdz.swift -o obj_to_usdz && ./obj_to_usdz house.obj house.usdz
import Foundation
import SceneKit

let args = CommandLine.arguments
guard args.count == 3 else {
    print("usage: obj_to_usdz in.obj out.usdz")
    exit(2)
}
let scene = try SCNScene(url: URL(fileURLWithPath: args[1]), options: nil)
let ok = scene.write(to: URL(fileURLWithPath: args[2]), options: nil, delegate: nil, progressHandler: nil)
print("wrote \(args[2]):", ok)
exit(ok ? 0 : 1)
