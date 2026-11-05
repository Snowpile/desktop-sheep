import CoreGraphics
import Foundation

/// Style B: smooth vector cartoon drawn with Core Graphics paths: soft radial gradients for
/// volume, one clean outer outline per group, anti-aliased edges.
enum VectorStyle {
    /// Sampled polygon for a shape, always wound the same way so unions fill correctly.
    static func polygon(_ shape: Shape) -> [P] {
        var pts: [P]
        switch shape {
        case let .ellipse(c, rx, ry, angle):
            pts = (0..<56).map { k in
                let t = Double(k) / 56 * 2 * .pi
                return (c + P(x: cos(t) * rx, y: sin(t) * ry)).rotated(angle, around: c)
            }
        case let .capsule(a, b, ra, rb):
            let d = b - a, L = max(d.length, 1e-6)
            let theta = atan2(d.y, d.x)
            let phi = asin(max(-1, min(1, (ra - rb) / L)))
            let n = 16
            pts = (0...n).map { k in // back arc around a
                let t = theta + .pi / 2 + phi + Double(k) / Double(n) * (.pi - 2 * phi)
                return a + P(x: cos(t) * ra, y: sin(t) * ra)
            } + (0...n).map { k in // front arc around b
                let t = theta - .pi / 2 - phi + Double(k) / Double(n) * (.pi + 2 * phi)
                return b + P(x: cos(t) * rb, y: sin(t) * rb)
            }
        case let .triangle(a, b, c, r):
            var v = [a, b, c]
            if area(v) < 0 { v.reverse() }
            pts = []
            for i in 0..<3 {
                let prev = v[(i + 2) % 3], cur = v[i], next = v[(i + 1) % 3]
                let n1 = normal(prev, cur), n2 = normal(cur, next)
                let t1 = atan2(n1.y, n1.x)
                var t2 = atan2(n2.y, n2.x)
                while t2 < t1 { t2 += 2 * .pi }
                for k in 0...6 {
                    let t = t1 + (t2 - t1) * Double(k) / 6
                    pts.append(cur + P(x: cos(t) * r, y: sin(t) * r))
                }
            }
        case .line:
            return []
        }
        if area(pts) < 0 { pts.reverse() }
        return pts
    }

    private static func area(_ p: [P]) -> Double {
        zip(p, p.dropFirst() + [p[0]]).reduce(0) { $0 + ($1.0.x * $1.1.y - $1.1.x * $1.0.y) } / 2
    }

    /// Outward normal of edge a→b for a positively wound polygon (y down).
    private static func normal(_ a: P, _ b: P) -> P {
        let d = b - a, l = max(d.length, 1e-9)
        return P(x: d.y / l, y: -d.x / l)
    }

    static func path(_ shape: Shape, scale: Double) -> CGPath {
        let path = CGMutablePath()
        if case let .line(points, _) = shape {
            path.addLines(between: points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) })
            return path
        }
        let pts = polygon(shape)
        path.addLines(between: pts.map { CGPoint(x: $0.x * scale, y: $0.y * scale) })
        path.closeSubpath()
        return path
    }

    static func cg(_ c: RGB) -> CGColor { CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a) }

    /// Draws the parts into `ctx` (already flipped so y grows downward), `scale` pixels per rig unit.
    static func draw(_ parts: [Part], in ctx: CGContext, scale s: Double) {
        let outlineWidth = 0.95 * s
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        // Soft ground shadow.
        ctx.saveGState()
        ctx.setFillColor(cg(RGB(0x1A1420, alpha: 0.16)))
        ctx.fillEllipse(in: CGRect(x: 13 * s, y: 58.6 * s, width: 32 * s, height: 3.4 * s))
        ctx.restoreGState()

        for g in Set(parts.map(\.group)).sorted() {
            let solids = parts.filter { $0.group == g && !$0.decal }
            let decals = parts.filter { $0.group == g && $0.decal }

            // Outline: every solid part stroked wide in a dark tint, then covered by the fills.
            if let first = solids.first {
                ctx.setFillColor(cg(outline(first.color)))
                ctx.setStrokeColor(cg(outline(first.color)))
                ctx.setLineWidth(outlineWidth * 2)
                for part in solids {
                    let p = path(part.shape, scale: s)
                    ctx.addPath(p); ctx.fillPath()
                    ctx.addPath(p); ctx.strokePath()
                }
            }
            for part in solids {
                let p = path(part.shape, scale: s)
                ctx.setFillColor(cg(part.color))
                ctx.addPath(p); ctx.fillPath()
                shadeGradient(part, path: p, in: ctx, scale: s)
            }

            ctx.saveGState()
            if !solids.isEmpty {
                let union = CGMutablePath()
                for part in solids { union.addPath(path(part.shape, scale: s)) }
                ctx.addPath(union)
                ctx.clip()
            }
            for part in decals {
                let p = path(part.shape, scale: s)
                if case let .line(_, w) = part.shape {
                    ctx.setStrokeColor(cg(part.color))
                    ctx.setLineWidth(w * s)
                    ctx.addPath(p); ctx.strokePath()
                } else {
                    ctx.setFillColor(cg(part.color))
                    ctx.addPath(p); ctx.fillPath()
                    if !PixelStyle.isFlatDecal(part) && part.volume > 0 {
                        shadeGradient(part, path: p, in: ctx, scale: s, strength: 0.7)
                    }
                }
            }
            ctx.restoreGState()
        }
    }

    static func outline(_ c: RGB) -> RGB { PixelStyle.outlineColor(for: c) }

    /// A soft light-to-shadow radial gradient across the part, lit from the top-left.
    static func shadeGradient(_ part: Part, path: CGPath, in ctx: CGContext, scale s: Double, strength: Double = 1) {
        guard part.volume > 0 else { return }
        let box = path.boundingBoxOfPath
        let r = max(box.width, box.height) * 0.62
        let center = CGPoint(x: box.midX - box.width * 0.22, y: box.midY - box.height * 0.3)
        let k = part.volume * strength
        let colors = [
            cg(part.color.shade(0.30 * k).with(alpha: 0.9)),
            cg(part.color.with(alpha: 0)),
            cg(part.color.shade(-0.30 * k).with(alpha: 0.85)),
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 0.5, 1.15]) else { return }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: r * 1.5,
                               options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }
}
