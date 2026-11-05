import Foundation

/// An RGBA sprite. Pixels are packed as 0xRRGGBBAA, row 0 at the top.
public struct ColorCanvas: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public internal(set) var pixels: [UInt32]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: 0, count: width * height)
    }

    public subscript(x: Int, y: Int) -> UInt32 {
        get { x >= 0 && y >= 0 && x < width && y < height ? pixels[y * width + x] : 0 }
        set { if x >= 0 && y >= 0 && x < width && y < height { pixels[y * width + x] = newValue } }
    }

    public func isSolid(_ x: Int, _ y: Int) -> Bool { self[x, y] & 0xFF == 0xFF }
    public var isBlank: Bool { pixels.allSatisfy { $0 & 0xFF == 0 } }
    /// True if any pixel is partly transparent (such as the ground shadow).
    public var hasTranslucent: Bool { pixels.contains { let a = $0 & 0xFF; return a > 0 && a < 0xFF } }

    static func pack(_ c: RGB) -> UInt32 {
        func b(_ v: Double) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return b(c.r) << 24 | b(c.g) << 16 | b(c.b) << 8 | b(c.a)
    }

    static func unpack(_ v: UInt32) -> RGB {
        RGB(r: Double(v >> 24 & 0xFF) / 255, g: Double(v >> 16 & 0xFF) / 255, b: Double(v >> 8 & 0xFF) / 255,
            a: Double(v & 0xFF) / 255)
    }

    /// Source-over blend.
    mutating func blend(_ x: Int, _ y: Int, _ c: RGB) {
        guard x >= 0, y >= 0, x < width, y < height, c.a > 0 else { return }
        if c.a >= 0.999 { pixels[y * width + x] = Self.pack(c); return }
        let under = Self.unpack(pixels[y * width + x])
        let a = c.a + under.a * (1 - c.a)
        guard a > 0 else { return }
        let mix = { (s: Double, d: Double) in (s * c.a + d * under.a * (1 - c.a)) / a }
        pixels[y * width + x] = Self.pack(RGB(r: mix(c.r, under.r), g: mix(c.g, under.g), b: mix(c.b, under.b), a: a))
    }

    mutating func recolorSolid(_ color: (Int, Int) -> UInt32) {
        for y in 0..<height { for x in 0..<width where isSolid(x, y) { pixels[y * width + x] = color(x, y) } }
    }

    mutating func clearSolid(where test: (Int, Int) -> Bool) {
        for y in 0..<height { for x in 0..<width where isSolid(x, y) && test(x, y) { pixels[y * width + x] = 0 } }
    }

    mutating func outlineSolid(_ color: UInt32) {
        let src = self
        for y in 0..<height { for x in 0..<width where src[x, y] & 0xFF == 0 {
            if [src.isSolid(x - 1, y), src.isSolid(x + 1, y), src.isSolid(x, y - 1), src.isSolid(x, y + 1)].contains(true) {
                pixels[y * width + x] = color
            }
        } }
    }

    /// Scales down around a bottom-center point (nearest neighbor).
    mutating func shrink(scale: Double, aroundX cx: Double, bottom: Double) {
        let src = self
        pixels = Array(repeating: 0, count: width * height)
        guard scale > 0.05 else { return }
        for y in 0..<height { for x in 0..<width {
            let sx = Int((cx + (Double(x) + 0.5 - cx) / scale).rounded(.down))
            let sy = Int((bottom + (Double(y) + 0.5 - bottom) / scale).rounded(.down))
            pixels[y * width + x] = src[sx, sy]
        } }
    }

    /// Rotates counter-clockwise on screen by quarter turns around (cx, cy).
    mutating func rotate(quarterTurns: Int, cx: Int, cy: Int) {
        for _ in 0..<((quarterTurns % 4 + 4) % 4) {
            let src = self
            for y in 0..<height { for x in 0..<width {
                pixels[y * width + x] = src[cx - (y - cy), cy + (x - cx)]
            } }
        }
    }
}

extension PetArt {
    /// Where the 64x64 pet rig sits in the sprite.
    static let rigOrigin = (x: 10, y: 16)
    /// Sprite row of the pet's ground line (feet stand on this edge).
    public static let groundRow = 76
    /// Effect layers are scaled by this to match the pet.
    static let layerScale = 1.45
    static let rotationCenter = (x: 40, y: 40)

    /// Sprite column where a climbing pet's feet touch the wall (right-facing, after rotation).
    public static let climbFootColumn = 75
    /// Sprite row a hanging pet's front paws grip (its front legs reach straight up).
    public static let hangGripRow = 41

    static func paletteRGB(_ i: UInt8) -> RGB {
        let p = palette[Int(i)]
        return RGB(r: Double(p.r) / 255, g: Double(p.g) / 255, b: Double(p.b) / 255, a: Double(p.a) / 255)
    }

    /// Fully opaque sprite pixel (used for hit testing; the shadow doesn't count).
    public static func isSolid(_ pixel: UInt32) -> Bool { pixel & 0xFF == 0xFF }

    /// Renders a pet in a pose: shaded 64x64 pixel art from the rig, with props and effects
    /// from the indexed effect layers scaled on top.
    public static func render(_ pose: Pose, animal: Animal = .sheep) -> ColorCanvas {
        var out = ColorCanvas(width: width, height: height)
        let liftPx = Int((Double(pose.lift) * layerScale).rounded())

        var behind = effectLayer(lift: pose.lift)
        drawGearBehind(&behind, pose.gear)
        drawFinaleBehind(&behind, pose.finale)
        composite(behind, onto: &out)

        if showsPet(pose.finale) {
            if pose.shadow { drawShadow(&out) }
            let image = PixelStyle.render(buildParts(animal, rigPose(from: pose)), shadow: false)
            for y in 0..<image.size { for x in 0..<image.size {
                if let c = image[x, y] { out.blend(x + rigOrigin.x, y + rigOrigin.y - liftPx, c) }
            } }
        }
        applyFinaleColors(&out, pose.finale)

        var front = effectLayer(lift: pose.lift)
        drawGearInFront(&front, pose.gear)
        drawFinaleFront(&front, pose.finale)
        composite(front, onto: &out)

        if pose.rotation % 4 != 0 {
            // Curled-up tumbles spin around the pet's middle; climbing pivots so the feet meet the wall.
            let center = pose.legs == .folded ? (x: 40, y: 52) : rotationCenter
            out.rotate(quarterTurns: pose.rotation, cx: center.x, cy: center.y)
        }
        return out
    }

    private static func effectLayer(lift: Int) -> PixelCanvas {
        var c = PixelCanvas(width: layerSize, height: layerSize)
        c.originX = bodyOrigin.x
        c.originY = bodyOrigin.y - lift
        return c
    }

    /// Scales an effect layer onto the sprite so its ground and pet center line up with the rig's.
    private static func composite(_ layer: PixelCanvas, onto out: inout ColorCanvas) {
        guard !layer.isBlank else { return }
        let layerCenter = Double(bodyOrigin.x + 18), layerGround = Double(layerSize - 1)
        let spriteCenter = Double(width) / 2
        for y in 0..<out.height { for x in 0..<out.width {
            let lx = Int((layerCenter + (Double(x) + 0.5 - spriteCenter) / layerScale).rounded(.down))
            let ly = Int((layerGround + 1 - (Double(groundRow) - (Double(y) + 0.5)) / layerScale).rounded(.down))
            let i = layer.pixel(lx, ly)
            if i != 0 { out.blend(x, y, paletteRGB(i)) }
        } }
    }

    private static func drawShadow(_ c: inout ColorCanvas) {
        let band = Shape.ellipse(c: RigPoint(x: Double(rigOrigin.x) + 29, y: Double(groundRow) + 0.3), rx: 16, ry: 1.7, angle: 0)
        for y in (groundRow - 2)...(groundRow + 2) { for x in 0..<c.width
            where band.distance(RigPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)) < 0 {
            c.blend(x, y, RGB(0x1A1420, alpha: 0.22))
        } }
    }

    /// Maps a frame's pose parameters onto the rig.
    static func rigPose(from pose: Pose) -> RigPose {
        var r = RigPose()
        let k = 1.4
        switch pose.legs {
        case let .standing(dx, lifted):
            r.swing = dx.map { Double($0) * 0.2 }
            r.lift = lifted.map { $0 ? 1.5 : 0 }
        case .folded:
            r.mode = pose.posture == .lying ? .lying : .sitting
        case .spread:
            r.swing = [-0.7, -0.5, 0.7, 0.5]
        case let .dangling(w):
            let s = Double(w) * 0.12
            r.swing = [s, -s, -s, s]
            if pose.gear == .grip {
                // Hanging on: front legs reach straight up to the edge.
                r.swing[2] = .pi - 0.12 + s
                r.swing[3] = .pi + 0.08 - s
            }
        }
        if r.mode == .standing {
            r.bodyDY = Double(pose.bodyDY) * k
            r.headDX = Double(pose.headDX) * k
            if pose.headDY >= 5 {
                // Head down to the ground (eating, digging).
                r.headDY = Double(pose.headDY) * k + 3
                r.headTilt = 0.35
            } else {
                r.headDY = Double(pose.headDY) * k
                r.headTilt = pose.headDY < 0 ? -0.12 * Double(-pose.headDY) : 0
            }
        }
        switch pose.eyes {
        case .open: r.eyes = .open
        case .closed: r.eyes = .closed
        case .wide: r.eyes = .wide
        case .happy: r.eyes = .happy
        }
        r.mouthOpen = pose.mouthOpen
        r.earAngle = pose.earUp ? -0.45 : 0
        r.tailAngle = -Double(pose.tailDY) * 0.35
        r.seasonal = pose.seasonal
        switch pose.effect {
        case .none: break
        case let .zzz(f): r.extra = .zzz; r.frame = f
        case let .call(f): r.extra = .call; r.frame = f
        case let .food(f): r.extra = .food; r.frame = f
        }
        return r
    }
}
