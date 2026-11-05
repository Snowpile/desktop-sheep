import Foundation

/// Style A: crisp pixel art at 64x64. Each part is shaded as a little dome lit from the
/// top-left and quantized to a 4-tone ramp; every group gets a 1px outline tinted from its
/// own color so overlapping parts (a near leg over the body) stay readable.
public enum PixelStyle {
    public static let size = 64

    public struct Image: Sendable {
        public var pixels: [RGB?]
        public let size: Int
        public subscript(x: Int, y: Int) -> RGB? {
            get { x >= 0 && y >= 0 && x < size && y < size ? pixels[y * size + x] : nil }
            set { if x >= 0 && y >= 0 && x < size && y < size { pixels[y * size + x] = newValue } }
        }
    }

    static let light: (Double, Double, Double) = {
        let v = (-0.55, -0.75, 0.9)
        let l = (v.0 * v.0 + v.1 * v.1 + v.2 * v.2).squareRoot()
        return (v.0 / l, v.1 / l, v.2 / l)
    }()

    /// Tone step for a point on a part: +1 highlight, 0 base, -1 / -2 shadows.
    public static func tone(_ part: Part, at p: RigPoint) -> Double {
        let (u, v) = part.shape.bulge(p)
        let r2 = min(u * u + v * v, 1)
        let h = (1 - r2).squareRoot()
        let d = u * light.0 + v * light.1 + h * light.2
        let step: Double = d > 0.86 ? 0.22 : (d > 0.42 ? 0 : (d > 0.05 ? -0.2 : -0.38))
        return step * part.volume
    }

    public static func isFlatDecal(_ part: Part) -> Bool {
        switch part.shape {
        case .line: return true
        case let .ellipse(_, rx, ry, _): return rx * ry < 3.5
        case let .capsule(a, b, ra, rb): return (b - a).length * (ra + rb) < 3
        case .triangle: return false
        }
    }

    /// Pixel bounds a part can touch (inclusive), so rendering only visits nearby pixels.
    static func bounds(_ shape: Shape) -> (x0: Int, y0: Int, x1: Int, y1: Int) {
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        func include(_ p: RigPoint, _ r: Double) {
            minX = min(minX, p.x - r); maxX = max(maxX, p.x + r)
            minY = min(minY, p.y - r); maxY = max(maxY, p.y + r)
        }
        switch shape {
        case let .ellipse(c, rx, ry, _): include(c, max(rx, ry))
        case let .capsule(a, b, ra, rb): include(a, ra); include(b, rb)
        case let .triangle(a, b, c, r): include(a, r); include(b, r); include(c, r)
        case let .line(points, w): points.forEach { include($0, w / 2 + 1) }
        }
        return (max(Int(minX) - 1, 0), max(Int(minY) - 1, 0), min(Int(maxX) + 1, size - 1), min(Int(maxY) + 1, size - 1))
    }

    public static func render(_ parts: [Part], shadow: Bool = true) -> Image {
        var img = Image(pixels: Array(repeating: nil, count: size * size), size: size)

        if shadow {
            // Soft ground shadow (a translucent dark band).
            let band = Shape.ellipse(c: RigPoint(x: 29, y: 60.3), rx: 16, ry: 1.7, angle: 0)
            let b = bounds(band)
            for y in b.y0...b.y1 { for x in b.x0...b.x1 where band.distance(RigPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)) < 0 {
                img[x, y] = RGB(0x1A1420, alpha: 0.22)
            } }
        }

        for g in Set(parts.map(\.group)).sorted() {
            let solids = parts.filter { $0.group == g && !$0.decal }
            let decals = parts.filter { $0.group == g && $0.decal }
            var mask = Array(repeating: false, count: size * size)
            var toneMap = Array(repeating: 0.0, count: size * size)
            var layer = Array<RGB?>(repeating: nil, count: size * size)
            var touched = (x0: size, y0: size, x1: 0, y1: 0)

            for part in solids {
                let b = bounds(part.shape)
                guard b.x0 <= b.x1, b.y0 <= b.y1 else { continue }
                touched = (min(touched.x0, b.x0), min(touched.y0, b.y0), max(touched.x1, b.x1), max(touched.y1, b.y1))
                for y in b.y0...b.y1 { for x in b.x0...b.x1 {
                    let p = RigPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                    guard part.shape.distance(p) < 0 else { continue }
                    let t = tone(part, at: p)
                    layer[y * size + x] = part.color.shade(t)
                    toneMap[y * size + x] = t
                    mask[y * size + x] = true
                } }
            }
            for part in decals {
                let b = bounds(part.shape)
                guard b.x0 <= b.x1, b.y0 <= b.y1 else { continue }
                for y in b.y0...b.y1 { for x in b.x0...b.x1 {
                    let i = y * size + x
                    let p = RigPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                    let inside: Bool
                    if case let .line(_, w) = part.shape {
                        inside = part.shape.distance(p) < max(0, 0.5 - w / 2)
                    } else {
                        inside = part.shape.distance(p) < 0
                    }
                    guard inside, mask[i] || solids.isEmpty else { continue }
                    let c = isFlatDecal(part) ? part.color : part.color.shade(toneMap[i] * part.volume)
                    if c.a >= 0.99 { layer[i] = c } else if let under = layer[i] ?? img.pixels[i] {
                        layer[i] = under.mix(c.with(alpha: 1), c.a).with(alpha: 1)
                    } else { layer[i] = c }
                } }
            }
            // Composite, then outline the group's silhouette.
            for i in 0..<(size * size) where layer[i] != nil { img.pixels[i] = layer[i] }
            guard !solids.isEmpty, touched.x0 <= touched.x1 else { continue }
            for y in max(touched.y0 - 1, 0)...min(touched.y1 + 1, size - 1) {
                for x in max(touched.x0 - 1, 0)...min(touched.x1 + 1, size - 1) where !mask[y * size + x] {
                    let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                    if let n = neighbors.first(where: { $0.0 >= 0 && $0.1 >= 0 && $0.0 < size && $0.1 < size && mask[$0.1 * size + $0.0] }),
                       let c = layer[n.1 * size + n.0] {
                        img[x, y] = outlineColor(for: c)
                    }
                }
            }
        }
        return img
    }

    public static func outlineColor(for c: RGB) -> RGB {
        RGB(r: c.r * 0.32 + 0.03, g: c.g * 0.26 + 0.02, b: c.b * 0.34 + 0.06)
    }
}
