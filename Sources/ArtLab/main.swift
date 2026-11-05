import AppKit
import SheepCore

/// Renders preview sheets of the candidate art styles:
///   swift run ArtLab [output-dir]   (default: docs/previews)
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/previews")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let cell = 64.0
let zoom = 4.0
let labelHeight = 26.0
let rowLabelWidth = 110.0
let background = RGB(0xF3F1EC)

func makeContext(width: Int, height: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Work in a y-down coordinate system like the rig.
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func drawText(_ text: String, at point: CGPoint, size: CGFloat, in ctx: CGContext, bold: Bool = false) {
    let ns = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ns
    let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: NSColor(white: 0.25, alpha: 1)])
    NSGraphicsContext.restoreGraphicsState()
}

func save(_ ctx: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
    print("wrote \(outDir.appendingPathComponent(name).path)")
}

/// Blits a pixel-style image with nearest-neighbor zoom.
func blit(_ img: PixelStyle.Image, in ctx: CGContext, at origin: CGPoint, zoom z: Double) {
    for y in 0..<img.size { for x in 0..<img.size {
        guard let c = img[x, y] else { continue }
        ctx.setFillColor(VectorStyle.cg(c))
        ctx.fill(CGRect(x: origin.x + CGFloat(Double(x) * z), y: origin.y + CGFloat(Double(y) * z), width: CGFloat(z), height: CGFloat(z)))
    } }
}

func sheet(style: String, title: String, draw: (Animal, RigPose, CGContext, CGPoint) -> Void) {
    let cols = previewPoses.count, rows = Animal.allCases.count
    let w = Int(rowLabelWidth + Double(cols) * cell * zoom), h = Int(labelHeight * 2 + Double(rows) * cell * zoom)
    let ctx = makeContext(width: w, height: h)
    ctx.setFillColor(VectorStyle.cg(background))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    drawText(title, at: CGPoint(x: 12, y: 6), size: 18, in: ctx, bold: true)
    for (c, pose) in previewPoses.enumerated() {
        drawText(pose.name, at: CGPoint(x: rowLabelWidth + Double(c) * cell * zoom + 12, y: labelHeight + 4), size: 15, in: ctx)
    }
    for (r, species) in Animal.allCases.enumerated() {
        let y = labelHeight * 2 + Double(r) * cell * zoom
        drawText(species.rawValue, at: CGPoint(x: 12, y: y + cell * zoom / 2 - 10), size: 16, in: ctx)
        for (c, pose) in previewPoses.enumerated() {
            let origin = CGPoint(x: rowLabelWidth + Double(c) * cell * zoom, y: y)
            // Alternate cell tint so frames are easy to tell apart.
            ctx.setFillColor(VectorStyle.cg((r + c) % 2 == 0 ? RGB(0xE9E6DF) : RGB(0xEFEDE7)))
            ctx.fill(CGRect(x: origin.x, y: origin.y, width: cell * zoom, height: cell * zoom))
            draw(species, pose, ctx, origin)
        }
    }
    save(ctx, "style-\(style).png")
}

sheet(style: "a-pixel", title: "Style A: shaded pixel art (64x64, shown 4x)") { species, pose, ctx, origin in
    blit(PixelStyle.render(buildParts(species, pose)), in: ctx, at: origin, zoom: zoom)
}

sheet(style: "b-vector", title: "Style B: vector cartoon (Core Graphics, shown 4x)") { species, pose, ctx, origin in
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y)
    VectorStyle.draw(buildParts(species, pose), in: ctx, scale: zoom)
    ctx.restoreGState()
}

// Actual on-screen size (Retina 2x): both styles at 64pt over a desktop-like background.
do {
    let poses = [previewPoses[0], previewPoses[1], previewPoses[4]]
    let unit = 2.0, cellPx = cell * unit
    let w = Int(cellPx * Double(Animal.allCases.count * poses.count) + 40), h = Int(cellPx * 2 + 90)
    let ctx = makeContext(width: w, height: h)
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [VectorStyle.cg(RGB(0x5C7FA8)), VectorStyle.cg(RGB(0xA9C3D9))] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: h), options: [])
    drawText("Actual size on a Retina display (64pt): A on top, B below", at: CGPoint(x: 12, y: 8), size: 15, in: ctx, bold: true)
    var x = 20.0
    for species in Animal.allCases {
        for pose in poses {
            blit(PixelStyle.render(buildParts(species, pose)), in: ctx, at: CGPoint(x: x, y: 40), zoom: unit)
            ctx.saveGState()
            ctx.translateBy(x: x, y: 50 + cellPx)
            VectorStyle.draw(buildParts(species, pose), in: ctx, scale: unit)
            ctx.restoreGState()
            x += cellPx
        }
    }
    save(ctx, "actual-size.png")
}

// Every behavior as the app draws it (pixel style with effects and props), 3x.
do {
    let picks: [(String, Behavior, Int)] = [
        ("stand", .stand, 0), ("walk", .walk, 1), ("run", .run, 0), ("sit", .sit, 0), ("sleep", .sleep, 3),
        ("eat", .eat, 1), ("call", .call, 4), ("climb", .climb, 1), ("hang", .hang, 0), ("tumble", .tumble, 2),
        ("dig", .dig, 0), ("butterfly", .butterfly, 2), ("nuzzle", .nuzzle, 2), ("play-fight", .playFight, 2),
        ("startled", .startled, 2), ("parachute", .parachute, 0), ("meteor", .meteor, 1), ("jetpack", .jetpack, 0),
        ("impact", .impact, 3), ("countdown", .countdown, 0),
    ]
    let z = 3.0, cellPx = Double(PetArt.width) * z
    let w = Int(rowLabelWidth + cellPx * Double(picks.count)), h = Int(labelHeight * 2 + cellPx * Double(Animal.allCases.count))
    let ctx = makeContext(width: w, height: h)
    ctx.setFillColor(VectorStyle.cg(background))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    drawText("In-app frames (style A with effects, shown 3x)", at: CGPoint(x: 12, y: 6), size: 18, in: ctx, bold: true)
    for (c, pick) in picks.enumerated() {
        drawText(pick.0, at: CGPoint(x: rowLabelWidth + Double(c) * cellPx + 8, y: labelHeight + 4), size: 13, in: ctx)
    }
    for (r, animal) in Animal.allCases.enumerated() {
        let y = labelHeight * 2 + Double(r) * cellPx
        drawText(animal.title, at: CGPoint(x: 12, y: y + cellPx / 2 - 10), size: 16, in: ctx)
        for (c, pick) in picks.enumerated() {
            let frames = PetArt.frames(for: pick.1, animal: animal)
            let canvas = PetArt.render(frames[pick.2 % frames.count], animal: animal)
            let ox = rowLabelWidth + Double(c) * cellPx
            ctx.setFillColor(VectorStyle.cg((r + c) % 2 == 0 ? RGB(0xE9E6DF) : RGB(0xEFEDE7)))
            ctx.fill(CGRect(x: ox, y: y, width: cellPx, height: cellPx))
            for py in 0..<canvas.height { for px in 0..<canvas.width {
                let v = canvas[px, py]
                guard v & 0xFF != 0 else { continue }
                ctx.setFillColor(CGColor(srgbRed: CGFloat(v >> 24 & 0xFF) / 255, green: CGFloat(v >> 16 & 0xFF) / 255,
                                         blue: CGFloat(v >> 8 & 0xFF) / 255, alpha: CGFloat(v & 0xFF) / 255))
                ctx.fill(CGRect(x: ox + Double(px) * z, y: y + Double(py) * z, width: z, height: z))
            } }
        }
    }
    save(ctx, "in-app-frames.png")
}
