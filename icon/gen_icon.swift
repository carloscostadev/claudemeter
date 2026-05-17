import AppKit
import Foundation

// Generate a 1024x1024 macOS-style icon for ClaudeMeter.
// Coral gradient background, rounded squircle, white gauge needle.

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS Big Sur squircle has corner radius ~22.37% of side, with 10% padding on the canvas.
let pad: CGFloat = size * 0.10
let rect = CGRect(x: pad, y: pad, width: size - 2*pad, height: size - 2*pad)
let radius = rect.width * 0.2237

let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path)
ctx.clip()

// Coral gradient (Claude palette): #FF7A59 → #E94F2A
let colors = [
    NSColor(srgbRed: 1.00, green: 0.478, blue: 0.349, alpha: 1).cgColor,
    NSColor(srgbRed: 0.913, green: 0.310, blue: 0.165, alpha: 1).cgColor,
] as CFArray
let cs = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: rect.minX, y: rect.maxY),
                       end:   CGPoint(x: rect.maxX, y: rect.minY),
                       options: [])

// Subtle inner highlight (top)
ctx.saveGState()
let hi = CGGradient(colorsSpace: cs,
                    colors: [
                        NSColor(white: 1, alpha: 0.18).cgColor,
                        NSColor(white: 1, alpha: 0.0).cgColor,
                    ] as CFArray,
                    locations: [0.0, 0.55])!
ctx.drawLinearGradient(hi,
                       start: CGPoint(x: rect.midX, y: rect.maxY),
                       end:   CGPoint(x: rect.midX, y: rect.midY),
                       options: [])
ctx.restoreGState()

// Gauge: arc 240° centered, white stroke, with ticks and a needle.
let center = CGPoint(x: rect.midX, y: rect.midY - rect.height*0.06)
let arcR  = rect.width * 0.34
let lineW = rect.width * 0.055

// Background arc (lighter)
ctx.setLineCap(.round)
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.30).cgColor)
ctx.setLineWidth(lineW)
let startA: CGFloat = .pi * 1.2   // 216°
let endA:   CGFloat = .pi * (-0.2) // -36° (i.e. 324°, going clockwise)
ctx.addArc(center: center, radius: arcR, startAngle: startA, endAngle: endA, clockwise: true)
ctx.strokePath()

// Foreground arc (filled portion ~67%)
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(lineW)
let progressEnd: CGFloat = startA - (startA - endA) * 0.67
ctx.addArc(center: center, radius: arcR, startAngle: startA, endAngle: progressEnd, clockwise: true)
ctx.strokePath()

// Needle
ctx.saveGState()
let needleAngle = progressEnd
let needleLen = arcR * 0.92
let needleEnd = CGPoint(x: center.x + cos(needleAngle) * needleLen,
                        y: center.y + sin(needleAngle) * needleLen)
ctx.setLineCap(.round)
ctx.setLineWidth(rect.width * 0.028)
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.move(to: center)
ctx.addLine(to: needleEnd)
ctx.strokePath()

// Hub
ctx.setFillColor(NSColor.white.cgColor)
let hubR = rect.width * 0.055
ctx.addEllipse(in: CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR*2, height: hubR*2))
ctx.fillPath()
ctx.setFillColor(NSColor(srgbRed: 0.913, green: 0.310, blue: 0.165, alpha: 1).cgColor)
let hubR2 = hubR * 0.45
ctx.addEllipse(in: CGRect(x: center.x - hubR2, y: center.y - hubR2, width: hubR2*2, height: hubR2*2))
ctx.fillPath()
ctx.restoreGState()

img.unlockFocus()

// Save PNG
guard let tiff = img.tiffRepresentation,
      let rep  = NSBitmapImageRep(data: tiff),
      let png  = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to create PNG\n", stderr); exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "claudemeter_1024.png"
try png.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
