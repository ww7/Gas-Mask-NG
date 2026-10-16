#!/usr/bin/env swift
// Run from the repository root. The vector is traced from the original 32px
// menuIcon@2x alpha mask, preserving its asymmetry, eye holes and filter shape.
import AppKit
import Foundation
let mask = NSImage(contentsOfFile: "Artwork/menu-mask.pdf")!
let size = NSSize(width:1024,height:1024)
let yellow = NSColor(srgbRed:1,green:215.0/255,blue:0,alpha:1)
let blue = NSColor(srgbRed:0,green:87.0/255,blue:183.0/255,alpha:1)
let symbol = NSImage(size:size)
symbol.lockFocus()
mask.draw(in:NSRect(x:205,y:205,width:614,height:614),from:.zero,operation:.sourceOver,fraction:1)
yellow.setFill()
NSRect(origin:.zero,size:size).fill(using:.sourceIn)
symbol.unlockFocus()
let icon = NSImage(size:size)
icon.lockFocus()
blue.setFill()
NSBezierPath(roundedRect:NSRect(x:82,y:82,width:860,height:860),xRadius:190,yRadius:190).fill()
symbol.draw(in:NSRect(origin:.zero,size:size),from:.zero,operation:.sourceOver,fraction:1)
icon.unlockFocus()
let master=NSBitmapImageRep(data:icon.tiffRepresentation!)!.representation(using:.png,properties:[:])!
try master.write(to:URL(fileURLWithPath:"Artwork/app-icon.png"))
// Export the existing asset-catalog slots with the system image resampler.
for folder in ["Assets.xcassets/AppIcon.appiconset", "Assets.xcassets/AboutIcon.imageset"] {
    let data = try Data(contentsOf:URL(fileURLWithPath:folder + "/Contents.json"))
    let catalog = try JSONSerialization.jsonObject(with:data) as! [String:Any]
    for image in catalog["images"] as! [[String:String]] {
        guard let filename=image["filename"] else { continue }
        let base=Int((image["size"] ?? "128x128").split(separator:"x")[0])!
        let pixels=base * Int(image["scale"]!.prefix(1))!
        let export=Process()
        export.executableURL=URL(fileURLWithPath:"/usr/bin/sips")
        export.arguments=["-z",String(pixels),String(pixels),"Artwork/app-icon.png","--out",folder + "/" + filename]
        export.standardOutput=FileHandle.nullDevice
        try export.run(); export.waitUntilExit()
        precondition(export.terminationStatus == 0)
    }
}
