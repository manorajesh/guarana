#!/usr/bin/env swift
// Renders the Guarana app icon (AppIcon.icns + a 1024px PNG) from the same
// guarana-berry geometry the menu bar icon uses in Sources/Guarana/main.swift.
//
// Usage: swift scripts/generate-icon.swift <output-dir>

import AppKit
import CoreGraphics

// MARK: - Glyph geometry (22pt menu bar coordinate space, y-up)

private func leafPaths() -> (back: CGPath, front: CGPath) {
    let leaf = CGMutablePath()
    leaf.move(to: CGPoint(x: 6.0, y: 13.6))
    leaf.addCurve(to: CGPoint(x: 9.4, y: 21.0),
                  control1: CGPoint(x: 5.6, y: 16.6), control2: CGPoint(x: 6.7, y: 20.8))
    leaf.addCurve(to: CGPoint(x: 13.2, y: 17.1),
                  control1: CGPoint(x: 12.0, y: 21.2), control2: CGPoint(x: 13.7, y: 19.5))
    leaf.addCurve(to: CGPoint(x: 6.0, y: 13.6),
                  control1: CGPoint(x: 11.1, y: 15.9), control2: CGPoint(x: 8.7, y: 14.5))
    leaf.closeSubpath()

    var t = CGAffineTransform(translationX: 9.6 + 4.2, y: 17.4 - 0.2)
    t = t.rotated(by: -42.0 * .pi / 180)
    t = t.translatedBy(x: -9.6, y: -17.4)
    return (leaf, leaf.copy(using: &t)!)
}

private let fruitRect = CGRect(x: 3.0, y: 2.2, width: 16.0, height: 16.0)
private let ringRect = CGRect(x: 6.1, y: 5.3, width: 9.8, height: 9.8)
private let seedRect = CGRect(x: 8.6, y: 7.8, width: 4.8, height: 4.8)

// MARK: - Helpers

private func color(_ white: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: white, green: white, blue: white, alpha: alpha)
}

private func squircle(_ rect: CGRect) -> CGPath {
    // Superellipse approximating Apple's continuous-corner icon shape.
    let n: CGFloat = 5.0
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let theta = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(theta), s = sin(theta)
        let x = pow(abs(c), 2 / n) * a * (c < 0 ? -1 : 1)
        let y = pow(abs(s), 2 / n) * b * (s < 0 ? -1 : 1)
        let p = CGPoint(x: rect.midX + x, y: rect.midY + y)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

private func fillVertical(_ ctx: CGContext, _ path: CGPath, top: CGColor, bottom: CGColor, evenOdd: Bool = false) {
    let box = path.boundingBoxOfPath
    ctx.saveGState()
    ctx.addPath(path)
    evenOdd ? ctx.clip(using: .evenOdd) : ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: box.midX, y: box.maxY),
                           end: CGPoint(x: box.midX, y: box.minY), options: [])
    ctx.restoreGState()
}

/// Soft top-lit bevel: a light rim along the upper edge, a darker one along the lower edge.
private func bevel(_ ctx: CGContext, _ path: CGPath, width: CGFloat, light: CGFloat, dark: CGFloat, evenOdd: Bool = false) {
    for (dy, c) in [(-width * 0.5, color(1, light)), (width * 0.5, color(0, dark))] {
        ctx.saveGState()
        ctx.addPath(path)
        evenOdd ? ctx.clip(using: .evenOdd) : ctx.clip()
        // Stroke the shape shifted, clipped to the original: produces an inner rim on one side.
        var shift = CGAffineTransform(translationX: 0, y: dy)
        ctx.addPath(path.copy(using: &shift)!)
        ctx.setStrokeColor(c)
        ctx.setLineWidth(width)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

private func withShadow(_ ctx: CGContext, offsetY: CGFloat, blur: CGFloat, alpha: CGFloat, _ body: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: offsetY), blur: blur, color: color(0, alpha))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

// MARK: - Render

private func render(size px: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let k = CGFloat(px) / 1024
    ctx.scaleBy(x: k, y: k)
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)

    // Outer tile, on Apple's 824pt icon grid inside the 1024 canvas.
    let outer = squircle(CGRect(x: 100, y: 100, width: 824, height: 824))
    withShadow(ctx, offsetY: -10, blur: 24, alpha: 0.28) {
        fillVertical(ctx, outer, top: color(1.0), bottom: color(0.965))
    }
    ctx.saveGState()
    ctx.addPath(outer); ctx.clip()
    ctx.addPath(outer); ctx.setStrokeColor(color(0.86)); ctx.setLineWidth(5); ctx.strokePath()
    ctx.restoreGState()

    // Raised inner plate.
    let plate = squircle(CGRect(x: 174, y: 174, width: 676, height: 676))
    withShadow(ctx, offsetY: -14, blur: 34, alpha: 0.16) {
        fillVertical(ctx, plate, top: color(0.985), bottom: color(0.925))
    }
    bevel(ctx, plate, width: 4, light: 0.9, dark: 0.04)

    // Glyph: centre the menu bar artwork on the plate.
    let (backLeaf, frontLeaf) = leafPaths()
    let fruit = CGMutablePath()
    fruit.addEllipse(in: fruitRect)
    fruit.addEllipse(in: ringRect)
    let seed = CGPath(ellipseIn: seedRect, transform: nil)

    let bounds = CGPath(ellipseIn: fruitRect, transform: nil).boundingBoxOfPath
        .union(backLeaf.boundingBoxOfPath).union(frontLeaf.boundingBoxOfPath)
    let scale: CGFloat = 400 / max(bounds.width, bounds.height)
    var g = CGAffineTransform(translationX: 512, y: 512 - 6)
    g = g.scaledBy(x: scale, y: scale)
    g = g.translatedBy(x: -bounds.midX, y: -bounds.midY)

    let back = backLeaf.copy(using: &g)!
    let front = frontLeaf.copy(using: &g)!
    let body = fruit.copy(using: &g)!
    let pit = seed.copy(using: &g)!
    let ringHole = CGPath(ellipseIn: ringRect, transform: &g)

    // Each layer is filled and bevelled before the next one stacks on top of it.
    withShadow(ctx, offsetY: -10, blur: 22, alpha: 0.24) {
        fillVertical(ctx, back, top: color(0.30), bottom: color(0.40))
        bevel(ctx, back, width: 6, light: 0.18, dark: 0.18)
    }
    withShadow(ctx, offsetY: -10, blur: 22, alpha: 0.24) {
        fillVertical(ctx, front, top: color(0.50), bottom: color(0.60))
        bevel(ctx, front, width: 6, light: 0.25, dark: 0.15)
    }
    withShadow(ctx, offsetY: -12, blur: 26, alpha: 0.30) {
        fillVertical(ctx, body, top: color(0.07), bottom: color(0.23), evenOdd: true)
        bevel(ctx, body, width: 7, light: 0.16, dark: 0.30, evenOdd: true)
    }

    // Recessed ring: inner shadow where the plate shows through.
    ctx.saveGState()
    ctx.addPath(ringHole); ctx.clip()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0, 0.35))
    let frame = CGMutablePath()
    frame.addRect(ringHole.boundingBoxOfPath.insetBy(dx: -60, dy: -60))
    frame.addPath(ringHole)
    ctx.addPath(frame); ctx.setFillColor(color(0)); ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()

    withShadow(ctx, offsetY: -8, blur: 16, alpha: 0.30) {
        fillVertical(ctx, pit, top: color(0.07), bottom: color(0.23))
        bevel(ctx, pit, width: 6, light: 0.16, dark: 0.30)
    }

    return ctx.makeImage()!
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try data.write(to: url)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources")
let fm = FileManager.default
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try writePNG(render(size: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try writePNG(render(size: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try writePNG(render(size: 1024), to: outDir.appendingPathComponent("AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outDir.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try fm.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { exit(1) }
print("Wrote \(outDir.path)/AppIcon.icns and AppIcon.png")
