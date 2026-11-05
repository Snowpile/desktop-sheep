import Foundation

/// A color with components in 0...1.
struct RGB {
    var r: Double, g: Double, b: Double, a: Double = 1

    init(_ hex: UInt32, alpha: Double = 1) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
        a = alpha
    }

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    func mix(_ o: RGB, _ t: Double) -> RGB {
        RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t, a: a + (o.a - a) * t)
    }

    /// Shadows lean cool and purple, highlights warm, like hand-picked pixel-art ramps.
    func shade(_ amount: Double) -> RGB {
        amount >= 0
            ? mix(RGB(0xFFF6E0), amount)
            : RGB(r: r * (1 + amount * 0.55), g: g * (1 + amount * 0.62), b: b * (1 + amount * 0.40) + 0.04 * -amount)
    }

    func with(alpha: Double) -> RGB { RGB(r: r, g: g, b: b, a: alpha) }
}

struct P { var x: Double, y: Double }

func + (a: P, b: P) -> P { P(x: a.x + b.x, y: a.y + b.y) }
func - (a: P, b: P) -> P { P(x: a.x - b.x, y: a.y - b.y) }
func * (a: P, k: Double) -> P { P(x: a.x * k, y: a.y * k) }

extension P {
    func rotated(_ angle: Double, around c: P) -> P {
        let d = self - c, s = sin(angle), k = cos(angle)
        return c + P(x: d.x * k - d.y * s, y: d.x * s + d.y * k)
    }
    var length: Double { (x * x + y * y).squareRoot() }
}

/// Primitive shapes in rig space (64x64 box, y down, ground at y = 60, pet faces right).
enum Shape {
    case ellipse(c: P, rx: Double, ry: Double, angle: Double)
    /// Tapered capsule from `a` (radius `ra`) to `b` (radius `rb`).
    case capsule(a: P, b: P, ra: Double, rb: Double)
    /// Triangle with rounded corners.
    case triangle(P, P, P, round: Double)
    /// Open stroke (whiskers, closed eyes, sound marks).
    case line([P], width: Double)

    /// Signed distance (negative inside).
    func distance(_ p: P) -> Double {
        switch self {
        case let .ellipse(c, rx, ry, angle):
            let q = p.rotated(-angle, around: c) - c
            let k = (q.x * q.x / (rx * rx) + q.y * q.y / (ry * ry)).squareRoot()
            return (k - 1) * min(rx, ry)
        case let .capsule(a, b, ra, rb):
            let ab = b - a, ap = p - a
            let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / max(ab.x * ab.x + ab.y * ab.y, 1e-9)))
            return (p - (a + ab * t)).length - (ra + (rb - ra) * t)
        case let .triangle(a, b, c, round):
            return triangleDistance(p, a, b, c) - round
        case let .line(points, width):
            var best = Double.infinity
            for (u, v) in zip(points, points.dropFirst()) {
                best = min(best, Shape.capsule(a: u, b: v, ra: width / 2, rb: width / 2).distance(p))
            }
            return best
        }
    }

    /// Local "bulge" coordinates used for shading: (u, v) in -1...1 across the shape.
    func bulge(_ p: P) -> (u: Double, v: Double) {
        switch self {
        case let .ellipse(c, rx, ry, angle):
            let q = p.rotated(-angle, around: c) - c
            return (q.x / rx, q.y / ry)
        case let .capsule(a, b, ra, rb):
            let ab = b - a, ap = p - a
            let len2 = max(ab.x * ab.x + ab.y * ab.y, 1e-9)
            let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / len2))
            let r = ra + (rb - ra) * t
            let d = p - (a + ab * t)
            return (d.x / max(r, 0.1), d.y / max(r, 0.1))
        case let .triangle(a, b, c, _):
            let cx = (a.x + b.x + c.x) / 3, cy = (a.y + b.y + c.y) / 3
            let size = max(abs(a.x - cx), abs(b.x - cx), abs(c.x - cx), abs(a.y - cy), abs(b.y - cy), abs(c.y - cy))
            return ((p.x - cx) / size, (p.y - cy) / size)
        case .line:
            return (0, 0)
        }
    }

    var boundsCenter: P {
        switch self {
        case let .ellipse(c, _, _, _): return c
        case let .capsule(a, b, _, _): return (a + b) * 0.5
        case let .triangle(a, b, c, _): return P(x: (a.x + b.x + c.x) / 3, y: (a.y + b.y + c.y) / 3)
        case let .line(points, _): return points[points.count / 2]
        }
    }
}

private func triangleDistance(_ p: P, _ a: P, _ b: P, _ c: P) -> Double {
    func seg(_ p: P, _ a: P, _ b: P) -> Double {
        let ab = b - a, ap = p - a
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / max(ab.x * ab.x + ab.y * ab.y, 1e-9)))
        return (p - (a + ab * t)).length
    }
    func cross(_ o: P, _ a: P, _ b: P) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
    let d = min(seg(p, a, b), seg(p, b, c), seg(p, c, a))
    let s1 = cross(a, b, p), s2 = cross(b, c, p), s3 = cross(c, a, p)
    let inside = (s1 >= 0 && s2 >= 0 && s3 >= 0) || (s1 <= 0 && s2 <= 0 && s3 <= 0)
    return inside ? -d : d
}

/// One drawable piece of a pet.
struct Part {
    var shape: Shape
    var color: RGB
    /// Parts in the same group share one outer outline and are drawn together.
    var group: Int
    /// Decals (markings, eyes) have no outline or volume and are clipped to their group.
    var decal = false
    /// Shading strength (0 = flat).
    var volume = 1.0
}

enum Eyes { case open, closed, happy, wide }
enum Mode { case standing, sitting, lying }
enum Extra { case none, zzz, call, food }

/// Pose parameters shared by every animal.
struct RigPose {
    var name = "stand"
    /// Leg swing in radians (+ = foot forward): back-far, back-near, front-far, front-near.
    var swing = [0.0, 0, 0, 0]
    var lift = [0.0, 0, 0, 0]
    var bodyDY = 0.0
    var bodyTilt = 0.0
    var headDX = 0.0
    var headDY = 0.0
    var headTilt = 0.0
    var earAngle = 0.0
    var tailAngle = 0.0
    var eyes = Eyes.open
    var mouthOpen = false
    var mode = Mode.standing
    var extra = Extra.none
    var frame = 0
}

enum Species: String, CaseIterable { case sheep, cat, dog, bunny, redPanda }

/// The key frames shown on the preview sheets.
let previewPoses: [RigPose] = {
    var walkA = RigPose(); walkA.name = "walk"
    walkA.swing = [0.35, -0.35, -0.35, 0.35]; walkA.lift = [0, 1.5, 1.5, 0]; walkA.tailAngle = 0.1
    var walkB = RigPose(); walkB.name = "walk 2"
    walkB.swing = [-0.35, 0.35, 0.35, -0.35]; walkB.lift = [1.5, 0, 0, 1.5]; walkB.bodyDY = -0.8; walkB.headDY = -0.5
    var run = RigPose(); run.name = "run"
    run.swing = [-0.75, -0.55, 0.75, 0.6]; run.lift = [1, 2, 2, 1]; run.bodyDY = -3; run.bodyTilt = -0.06
    run.headDX = 1.5; run.earAngle = -0.5; run.tailAngle = -0.6
    var sit = RigPose(); sit.name = "sit"; sit.mode = .sitting; sit.tailAngle = 0.5
    var sleep = RigPose(); sleep.name = "sleep"; sleep.mode = .lying; sleep.eyes = .closed; sleep.extra = .zzz
    sleep.earAngle = 0.4; sleep.tailAngle = 0.9
    var eat = RigPose(); eat.name = "eat"; eat.headDX = 3; eat.headDY = 13; eat.headTilt = 0.35; eat.eyes = .happy
    eat.extra = .food; eat.swing = [0, 0, 0.12, 0.12]; eat.tailAngle = -0.2
    var call = RigPose(); call.name = "call"; call.headDY = -2; call.headTilt = -0.3; call.mouthOpen = true
    call.eyes = .happy; call.extra = .call; call.earAngle = -0.3; call.tailAngle = -0.3
    var fall = RigPose(); fall.name = "fall"; fall.swing = [-0.7, -0.5, 0.7, 0.5]; fall.eyes = .wide
    fall.mouthOpen = true; fall.earAngle = -0.8; fall.tailAngle = -0.8; fall.bodyDY = -4
    return [RigPose(), walkA, walkB, run, sit, sleep, eat, call, fall]
}()
