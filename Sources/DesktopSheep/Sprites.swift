import AppKit
import SheepCore

/// Turns SheepCore pixel canvases into cached CGImages (mirrored for left-facing sheep).
@MainActor
final class Sprites {
    static let shared = Sprites()

    /// Screen points per art pixel.
    let scale: CGFloat = 1.5
    var size: CGSize { CGSize(width: CGFloat(PetArt.width) * scale, height: CGFloat(PetArt.height) * scale) }

    private struct Key: Hashable {
        let pose: Pose
        let animal: Animal
        let mirrored: Bool
    }

    private struct CanvasKey: Hashable {
        let pose: Pose
        let animal: Animal
    }

    private var canvases: [CanvasKey: ColorCanvas] = [:]
    private var images: [Key: CGImage] = [:]

    func canvas(for pose: Pose, animal: Animal) -> ColorCanvas {
        let key = CanvasKey(pose: pose, animal: animal)
        if let c = canvases[key] { return c }
        let c = PetArt.render(pose, animal: animal)
        canvases[key] = c
        return c
    }

    func image(for pose: Pose, animal: Animal, facing: Facing) -> CGImage? {
        let key = Key(pose: pose, animal: animal, mirrored: facing == .left)
        if let image = images[key] { return image }
        guard let image = Self.makeImage(canvas(for: pose, animal: animal), mirrored: key.mirrored) else { return nil }
        images[key] = image
        return image
    }

    /// True if the art pixel under a point (in the sprite window's coordinates) is not transparent.
    func isOpaque(pose: Pose, animal: Animal, facing: Facing, at point: CGPoint) -> Bool {
        let c = canvas(for: pose, animal: animal)
        var px = Int(point.x / scale)
        let py = c.height - 1 - Int(point.y / scale)
        if facing == .left { px = c.width - 1 - px }
        // Treat pixels next to the pet as part of it too, so it's easy to grab.
        for dy in -1...1 { for dx in -1...1 where c.isSolid(px + dx, py + dy) { return true } }
        return false
    }

    static func makeImage(_ c: ColorCanvas, mirrored: Bool) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: c.width * c.height * 4)
        for y in 0..<c.height {
            for x in 0..<c.width {
                let v = c[mirrored ? c.width - 1 - x : x, y]
                let a = UInt32(v & 0xFF)
                let i = (y * c.width + x) * 4
                bytes[i] = UInt8((v >> 24 & 0xFF) * a / 255) // premultiplied
                bytes[i + 1] = UInt8((v >> 16 & 0xFF) * a / 255)
                bytes[i + 2] = UInt8((v >> 8 & 0xFF) * a / 255)
                bytes[i + 3] = UInt8(a)
            }
        }
        return cgImage(bytes, width: c.width, height: c.height)
    }

    private static func cgImage(_ bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Indexed images (treats).
    static func makeImage(_ c: PixelCanvas, mirrored: Bool) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: c.width * c.height * 4)
        for y in 0..<c.height {
            for x in 0..<c.width {
                let color = PetArt.palette[Int(c.pixel(mirrored ? c.width - 1 - x : x, y))]
                let i = (y * c.width + x) * 4
                let a = UInt16(color.a)
                // Premultiplied alpha.
                bytes[i] = UInt8(UInt16(color.r) * a / 255)
                bytes[i + 1] = UInt8(UInt16(color.g) * a / 255)
                bytes[i + 2] = UInt8(UInt16(color.b) * a / 255)
                bytes[i + 3] = color.a
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: c.width, height: c.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: c.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Small colored sheep for the menu bar.
    func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18))
        var pose = Pose()
        pose.shadow = false
        let body = CGRect(x: 10, y: 28, width: 64, height: 50)
        if let cg = self.image(for: pose, animal: .sheep, facing: .right)?.cropping(to: body) {
            image.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            NSGraphicsContext.current?.cgContext.interpolationQuality = .none
            NSGraphicsContext.current?.cgContext.draw(cg, in: CGRect(x: 0, y: 0, width: 22, height: 17.6))
            image.unlockFocus()
        }
        return image
    }
}
