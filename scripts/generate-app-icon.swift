import AppKit
import CoreGraphics
import Foundation

struct IconSlot {
    let filename: String
    let pixels: Int
}

let slots: [IconSlot] = [
    .init(filename: "AppIcon-16.png", pixels: 16),
    .init(filename: "AppIcon-16@2x.png", pixels: 32),
    .init(filename: "AppIcon-32.png", pixels: 32),
    .init(filename: "AppIcon-32@2x.png", pixels: 64),
    .init(filename: "AppIcon-128.png", pixels: 128),
    .init(filename: "AppIcon-128@2x.png", pixels: 256),
    .init(filename: "AppIcon-256.png", pixels: 256),
    .init(filename: "AppIcon-256@2x.png", pixels: 512),
    .init(filename: "AppIcon-512.png", pixels: 512),
    .init(filename: "AppIcon-512@2x.png", pixels: 1024)
]

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for slot in slots {
    let image = renderIcon(pixels: slot.pixels)
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(slot.filename)")
    }
    try data.write(to: outputDirectory.appendingPathComponent(slot.filename), options: .atomic)
}

func renderIcon(pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create icon context")
    }

    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)

    let iconRect = CGRect(x: size * 0.045, y: size * 0.045, width: size * 0.91, height: size * 0.91)
    let iconPath = CGPath(roundedRect: iconRect, cornerWidth: size * 0.215, cornerHeight: size * 0.215, transform: nil)
    context.addPath(iconPath)
    context.clip()

    context.setFillColor(cgColor(0.975, 0.978, 0.982, 1))
    context.fill(iconRect)

    drawHeadsetNote(context: context, size: size)

    context.resetClip()
    context.addPath(iconPath)
    context.setStrokeColor(cgColor(0.560, 0.600, 0.650, 0.20))
    context.setLineWidth(max(size * 0.008, 1))
    context.strokePath()

    guard let image = context.makeImage() else {
        fatalError("Could not render icon")
    }
    return image
}

func drawHeadsetNote(context: CGContext, size: CGFloat) {
    let gray = cgColor(0.560, 0.570, 0.585, 1)
    let blue = cgColor(0.070, 0.560, 0.970, 1)
    let padWhite = cgColor(1, 1, 1, 1)

    context.setStrokeColor(gray)
    context.setFillColor(gray)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    context.setLineWidth(size * 0.115)
    context.addArc(
        center: CGPoint(x: size * 0.500, y: size * 0.550),
        radius: size * 0.305,
        startAngle: CGFloat.pi * 0.02,
        endAngle: CGFloat.pi * 0.98,
        clockwise: true
    )
    context.strokePath()

    let leftCup = CGMutablePath()
    leftCup.move(to: CGPoint(x: size * 0.252, y: size * 0.505))
    leftCup.addCurve(to: CGPoint(x: size * 0.205, y: size * 0.742), control1: CGPoint(x: size * 0.202, y: size * 0.548), control2: CGPoint(x: size * 0.185, y: size * 0.664))
    leftCup.addLine(to: CGPoint(x: size * 0.270, y: size * 0.805))
    leftCup.addCurve(to: CGPoint(x: size * 0.352, y: size * 0.768), control1: CGPoint(x: size * 0.308, y: size * 0.814), control2: CGPoint(x: size * 0.342, y: size * 0.797))
    leftCup.addCurve(to: CGPoint(x: size * 0.335, y: size * 0.515), control1: CGPoint(x: size * 0.386, y: size * 0.670), control2: CGPoint(x: size * 0.374, y: size * 0.548))
    leftCup.addCurve(to: CGPoint(x: size * 0.252, y: size * 0.505), control1: CGPoint(x: size * 0.314, y: size * 0.498), control2: CGPoint(x: size * 0.282, y: size * 0.494))
    leftCup.closeSubpath()
    context.addPath(leftCup)
    context.fillPath()

    context.setFillColor(padWhite)
    fillRoundedRect(context: context, x: size * 0.258, y: size * 0.560, width: size * 0.070, height: size * 0.175, radius: size * 0.035)

    context.setFillColor(gray)

    let rightCup = CGMutablePath()
    rightCup.move(to: CGPoint(x: size * 0.748, y: size * 0.505))
    rightCup.addCurve(to: CGPoint(x: size * 0.795, y: size * 0.742), control1: CGPoint(x: size * 0.798, y: size * 0.548), control2: CGPoint(x: size * 0.815, y: size * 0.664))
    rightCup.addLine(to: CGPoint(x: size * 0.730, y: size * 0.805))
    rightCup.addCurve(to: CGPoint(x: size * 0.648, y: size * 0.768), control1: CGPoint(x: size * 0.692, y: size * 0.814), control2: CGPoint(x: size * 0.658, y: size * 0.797))
    rightCup.addCurve(to: CGPoint(x: size * 0.665, y: size * 0.515), control1: CGPoint(x: size * 0.614, y: size * 0.670), control2: CGPoint(x: size * 0.626, y: size * 0.548))
    rightCup.addCurve(to: CGPoint(x: size * 0.748, y: size * 0.505), control1: CGPoint(x: size * 0.686, y: size * 0.498), control2: CGPoint(x: size * 0.718, y: size * 0.494))
    rightCup.closeSubpath()
    context.addPath(rightCup)
    context.fillPath()

    context.setFillColor(padWhite)
    fillRoundedRect(context: context, x: size * 0.672, y: size * 0.560, width: size * 0.070, height: size * 0.175, radius: size * 0.035)

    context.setStrokeColor(blue)
    context.setFillColor(blue)
    context.setLineWidth(size * 0.085)
    context.move(to: CGPoint(x: size * 0.555, y: size * 0.350))
    context.addLine(to: CGPoint(x: size * 0.555, y: size * 0.632))
    context.strokePath()

    let flagPath = CGMutablePath()
    flagPath.move(to: CGPoint(x: size * 0.555, y: size * 0.350))
    flagPath.addLine(to: CGPoint(x: size * 0.725, y: size * 0.306))
    flagPath.addLine(to: CGPoint(x: size * 0.725, y: size * 0.420))
    flagPath.addLine(to: CGPoint(x: size * 0.555, y: size * 0.464))
    flagPath.closeSubpath()
    context.addPath(flagPath)
    context.fillPath()

    context.fillEllipse(in: CGRect(x: size * 0.375, y: size * 0.610, width: size * 0.230, height: size * 0.155))
}

func fillRoundedRect(context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) {
    let path = CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.fillPath()
}

func cgColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}
