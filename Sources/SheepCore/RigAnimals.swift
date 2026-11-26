import Foundation

/// Draw order of part groups.
enum G {
    static let farLegs = 0, tail = 1, body = 2, nearLegs = 3, farEar = 4, head = 5, nearEar = 6, fx = 7
}

private let ground = 60.0
/// Rig row a hanging pet's front paws grip (`PetArt.hangGripRow` in sprite rows).
private let gripY = 25.0

/// Per-species proportions and colors.
private struct Spec {
    var bodyC: RigPoint
    var bodyR: (x: Double, y: Double)
    var hipX: Double
    var shoulderX: Double
    var legTop: Double
    var legW: (top: Double, bottom: Double)
    var farOffset = -3.0
    var headC: RigPoint
    var headR: (x: Double, y: Double)
    var fur: RGB
    var dark: RGB
    var belly: RGB
    var leg: RGB
    var paw: RGB
    var eye = RGB(0x2B1E2A)
    var showLegs = true
}

private func spec(_ s: Animal) -> Spec {
    switch s {
    case .sheep:
        return Spec(bodyC: RigPoint(x: 27, y: 39), bodyR: (14, 9.5), hipX: 19, shoulderX: 34, legTop: 45, legW: (1.15, 1.0),
                    headC: RigPoint(x: 46, y: 31), headR: (6.2, 7.2),
                    fur: RGB(0xF4EFE4), dark: RGB(0x4A4048), belly: RGB(0xE4DCCC), leg: RGB(0x4A4048), paw: RGB(0x2C252D))
    case .cat:
        return Spec(bodyC: RigPoint(x: 28, y: 41), bodyR: (14.5, 7.5), hipX: 19, shoulderX: 36, legTop: 44, legW: (2.4, 1.9),
                    headC: RigPoint(x: 46.5, y: 30), headR: (8.4, 7.6),
                    fur: RGB(0xEE9A4E), dark: RGB(0xC2672C), belly: RGB(0xFCEBD3), leg: RGB(0xEE9A4E), paw: RGB(0xFCEBD3))
    case .dog:
        return Spec(bodyC: RigPoint(x: 27, y: 40), bodyR: (14.5, 8.5), hipX: 18, shoulderX: 35, legTop: 45, legW: (2.7, 2.2),
                    headC: RigPoint(x: 46, y: 29), headR: (8.2, 7.6),
                    fur: RGB(0xD08F4E), dark: RGB(0x6E4427), belly: RGB(0xF8F0E6), leg: RGB(0xD08F4E), paw: RGB(0xF8F0E6))
    case .bunny:
        return Spec(bodyC: RigPoint(x: 27, y: 46), bodyR: (13, 9.5), hipX: 21, shoulderX: 36, legTop: 50, legW: (1.9, 1.6),
                    headC: RigPoint(x: 43.5, y: 37), headR: (7.6, 7.0),
                    fur: RGB(0xC9C0CF), dark: RGB(0x9A90A3), belly: RGB(0xF7F1F4), leg: RGB(0xC9C0CF), paw: RGB(0xF7F1F4))
    case .redPanda:
        return Spec(bodyC: RigPoint(x: 28, y: 40), bodyR: (14.5, 8), hipX: 19, shoulderX: 36, legTop: 45, legW: (2.3, 1.9),
                    headC: RigPoint(x: 46.5, y: 30), headR: (8.6, 7.6),
                    fur: RGB(0xCC5A2C), dark: RGB(0x3A211B), belly: RGB(0x3A211B), leg: RGB(0x3A211B), paw: RGB(0x2A1714))
    case .pig:
        return Spec(bodyC: RigPoint(x: 27, y: 42), bodyR: (15, 9.5), hipX: 19, shoulderX: 35, legTop: 48, legW: (2.4, 2.0),
                    headC: RigPoint(x: 45.5, y: 34), headR: (8, 7.4),
                    fur: RGB(0xF5A9B8), dark: RGB(0xD9788E), belly: RGB(0xFAC6CF), leg: RGB(0xF5A9B8), paw: RGB(0x9A5563))
    case .hippo:
        return Spec(bodyC: RigPoint(x: 27, y: 41), bodyR: (16, 10.5), hipX: 18, shoulderX: 36, legTop: 50, legW: (3.0, 2.7),
                    headC: RigPoint(x: 44.5, y: 34), headR: (8, 7.2),
                    fur: RGB(0x9E93B8), dark: RGB(0x7A6E94), belly: RGB(0xE5B7C7), leg: RGB(0x9E93B8), paw: RGB(0x7F7499))
    case .elephant:
        return Spec(bodyC: RigPoint(x: 26, y: 39), bodyR: (15.5, 10.5), hipX: 18, shoulderX: 34, legTop: 47, legW: (3.0, 2.8),
                    headC: RigPoint(x: 43.5, y: 30), headR: (8.5, 8.2),
                    fur: RGB(0xA9B1C2), dark: RGB(0x7F889C), belly: RGB(0xBFC6D4), leg: RGB(0xA9B1C2), paw: RGB(0xEDE6D8))
    case .flyingSquirrel:
        return Spec(bodyC: RigPoint(x: 28, y: 46), bodyR: (12, 7.5), hipX: 21, shoulderX: 34, legTop: 50, legW: (1.7, 1.4),
                    headC: RigPoint(x: 42.5, y: 38), headR: (7.2, 6.6),
                    fur: RGB(0xA38F7E), dark: RGB(0x6B584B), belly: RGB(0xF4EDE2), leg: RGB(0xA38F7E), paw: RGB(0xF4EDE2))
    case .tiger:
        return Spec(bodyC: RigPoint(x: 27, y: 40), bodyR: (16, 8.5), hipX: 18, shoulderX: 36, legTop: 45, legW: (2.8, 2.4),
                    headC: RigPoint(x: 47, y: 29), headR: (8.6, 7.8),
                    fur: RGB(0xF08A2C), dark: RGB(0x2E2220), belly: RGB(0xFFF4E6), leg: RGB(0xF08A2C), paw: RGB(0xFFF4E6))
    }
}

/// Builds the list of parts for an animal in a pose.
public func buildParts(_ species: Animal, _ pose: RigPose) -> [Part] {
    var b = Builder(species: species, spec: spec(species), pose: pose)
    b.build()
    return b.parts
}

private struct Builder {
    let species: Animal
    let spec: Spec
    let pose: RigPose
    var parts: [Part] = []

    // Pose-derived transforms.
    var bodyCenter: RigPoint = RigPoint(x: 0, y: 0)
    var bodyAngle = 0.0
    var headCenter: RigPoint = RigPoint(x: 0, y: 0)
    var headAngle = 0.0
    /// Where each leg's foot ended up (standing legs only).
    var feet = [RigPoint](repeating: RigPoint(x: 0, y: 0), count: 4)

    init(species: Animal, spec: Spec, pose: RigPose) {
        self.species = species
        self.spec = spec
        self.pose = pose
    }

    mutating func add(_ shape: Shape, _ color: RGB, _ group: Int, decal: Bool = false, volume: Double = 1) {
        parts.append(Part(shape: shape, color: color, group: group, decal: decal, volume: volume))
    }

    /// Maps a point from the standing rest pose onto the posed body.
    func body(_ p: RigPoint) -> RigPoint {
        (p + RigPoint(x: 0, y: bodyShiftY)).rotated(bodyAngle, around: pivot) + bodyOffset
    }

    var pivot: RigPoint {
        pose.mode == .sitting ? RigPoint(x: spec.hipX - 3, y: ground - 4) : spec.bodyC
    }

    var bodyShiftY: Double {
        switch pose.mode {
        case .standing: return pose.bodyDY
        case .sitting: return 0
        case .lying: return ground - spec.bodyR.y - 0.5 - spec.bodyC.y
        }
    }

    var bodyOffset: RigPoint {
        pose.mode == .sitting ? RigPoint(x: 0, y: (ground - 4) - (spec.bodyC.y + spec.bodyR.y * 0.55)) : RigPoint(x: 0, y: 0)
    }

    /// Maps a head-local offset to the posed head.
    func head(_ dx: Double, _ dy: Double) -> RigPoint {
        (headCenter + RigPoint(x: dx, y: dy)).rotated(headAngle, around: headCenter)
    }

    mutating func build() {
        bodyAngle = pose.mode == .sitting ? -0.42 : pose.bodyTilt
        let neck = RigPoint(x: spec.shoulderX + 3, y: spec.bodyC.y - spec.bodyR.y * 0.4)
        let neckMoved = body(neck) - neck
        var hc = spec.headC + neckMoved + RigPoint(x: pose.headDX, y: pose.headDY)
        if pose.mode == .lying { hc = RigPoint(x: spec.headC.x + 3, y: ground - spec.headR.y - 0.5) }
        if pose.mode == .sitting { hc = hc + RigPoint(x: -1, y: 1) }
        headCenter = hc
        headAngle = pose.headTilt

        legs()
        tail()
        torso()
        headParts()
        seasonalParts()
        effects()
    }

    // MARK: Seasonal touches

    mutating func seasonalParts() {
        switch pose.seasonal {
        case .none:
            break
        case .santaHat:
            // A floppy red hat with white trim, tip flopping back, pompom at the end.
            let red = RGB(0xD8343F), white = RGB(0xFAF6F0)
            let top = spec.headR.y
            let left = head(-5.5, -top + 2.2), right = head(4.5, -top + 1.4)
            let tip = head(-8.5, -top - 7.5)
            add(.triangle(left, right, tip, round: 1.0), red, G.nearEar)
            add(.capsule(a: head(-6.5, -top + 2.4), b: head(5.5, -top + 1.6), ra: 1.6, rb: 1.6), white, G.nearEar)
            add(.ellipse(c: tip + RigPoint(x: -0.6, y: 0.4), rx: 1.9, ry: 1.9, angle: 0), white, G.nearEar)
        case .pumpkin:
            // A little jack-o'-lantern keeping resting pets company.
            // Only beside resting pets; eating pets munch a small one instead (see effects).
            guard pose.mode != .standing, pose.extra != .food else { break }
            let dx = pose.mode == .lying ? spec.headR.x + 4.5 : 10
            pumpkin(at: RigPoint(x: min(head(0, 0).x + dx, 61), y: ground - 3.6), size: 1)
        }
    }

    mutating func pumpkin(at c: RigPoint, size k: Double) {
        let orange = RGB(0xF08A24), dark = RGB(0x3A2416)
        add(.ellipse(c: c + RigPoint(x: -1.6 * k, y: 0), rx: 2.4 * k, ry: 3.2 * k, angle: 0), orange.shade(-0.1), G.fx)
        add(.ellipse(c: c + RigPoint(x: 1.6 * k, y: 0), rx: 2.4 * k, ry: 3.2 * k, angle: 0), orange.shade(-0.1), G.fx)
        add(.ellipse(c: c, rx: 2.4 * k, ry: 3.4 * k, angle: 0), orange, G.fx)
        add(.capsule(a: c + RigPoint(x: 0, y: -3.2 * k), b: c + RigPoint(x: 0.8 * k, y: -4.8 * k), ra: 0.7 * k, rb: 0.5 * k), RGB(0x5A7A2C), G.fx)
        if k >= 1 {
            add(.triangle(c + RigPoint(x: -2.4, y: -1), c + RigPoint(x: -1.2, y: -1), c + RigPoint(x: -1.8, y: -2), round: 0.1), dark, G.fx, decal: true)
            add(.triangle(c + RigPoint(x: 1.2, y: -1), c + RigPoint(x: 2.4, y: -1), c + RigPoint(x: 1.8, y: -2), round: 0.1), dark, G.fx, decal: true)
            add(.capsule(a: c + RigPoint(x: -2, y: 1.2), b: c + RigPoint(x: 2, y: 1.2), ra: 0.6, rb: 0.6), dark, G.fx, decal: true)
        }
    }

    // MARK: Legs

    mutating func legs() {
        let L = ground - spec.legTop
        switch pose.mode {
        case .standing:
            for i in 0..<4 {
                let far = i % 2 == 0
                let baseX = (i < 2 ? spec.hipX : spec.shoulderX) + (far ? spec.farOffset : 0)
                if cos(pose.swing[i]) < 0 {
                    // Reaching up (hanging from an edge): the leg leaves from the top of the shoulder
                    // so it doesn't cross the body, and the paw stays on the grip line.
                    let top = body(RigPoint(x: baseX + 1, y: spec.bodyC.y - spec.bodyR.y * 0.45))
                    let foot = RigPoint(x: top.x + sin(pose.swing[i]) * (top.y - gripY), y: gripY)
                    leg(top: top, foot: foot, far: far, back: i < 2)
                    continue
                }
                let top = body(RigPoint(x: baseX, y: spec.legTop - 2))
                let len = max(ground - top.y - pose.lift[i], 4)
                var foot = top + RigPoint(x: sin(pose.swing[i]) * len, y: cos(pose.swing[i]) * len)
                foot.y = min(foot.y, ground - pose.lift[i])
                feet[i] = foot
                leg(top: top, foot: foot, far: far, back: i < 2)
            }
        case .sitting:
            // Front legs straight down from the raised chest; hind legs folded into a haunch.
            for far in [true, false] {
                let top = body(RigPoint(x: spec.shoulderX + (far ? spec.farOffset : 0), y: spec.legTop - 2))
                leg(top: top, foot: RigPoint(x: top.x + 1, y: ground), far: far, back: false)
            }
            add(.ellipse(c: RigPoint(x: spec.hipX + 1, y: ground - 5.5), rx: 7.5, ry: 5.5, angle: -0.2), spec.fur, G.nearLegs)
            add(.ellipse(c: RigPoint(x: spec.hipX + 5, y: ground - 1.4), rx: 4.2, ry: 1.6, angle: 0), spec.paw, G.nearLegs)
            _ = L
        case .lying:
            add(.ellipse(c: RigPoint(x: spec.shoulderX + 6, y: ground - 1.5), rx: 4, ry: 1.7, angle: 0), spec.paw, G.nearLegs)
            add(.ellipse(c: RigPoint(x: spec.shoulderX + 3, y: ground - 1.3), rx: 3.6, ry: 1.5, angle: 0), spec.paw.shade(-0.2), G.farLegs)
            add(.ellipse(c: RigPoint(x: spec.hipX - 2, y: ground - 1.4), rx: 4, ry: 1.6, angle: 0), spec.paw, G.nearLegs)
        }
    }

    mutating func leg(top: RigPoint, foot: RigPoint, far: Bool, back: Bool) {
        let group = far ? G.farLegs : G.nearLegs
        let color = far ? spec.leg.shade(-0.28) : spec.leg
        if species == .bunny && back {
            // Big hind foot flat on the ground.
            add(.ellipse(c: RigPoint(x: foot.x + 2, y: foot.y - 1.6), rx: 5.5, ry: 1.8, angle: 0), far ? spec.paw.shade(-0.25) : spec.paw, group)
            return
        }
        // Slightly bent leg: upper and lower segment.
        let knee = (top + foot) * 0.5 + RigPoint(x: back ? -0.8 : 0.6, y: 0)
        add(.capsule(a: top, b: knee, ra: spec.legW.top * (back ? 1.35 : 1.1), rb: spec.legW.bottom * 1.05), color, group)
        add(.capsule(a: knee, b: foot + RigPoint(x: 0, y: -1), ra: spec.legW.bottom * 1.05, rb: spec.legW.bottom), color, group)
        let pawColor = far ? spec.paw.shade(-0.25) : spec.paw
        add(.ellipse(c: foot + RigPoint(x: 0.9, y: -1.1), rx: spec.legW.bottom * 1.35, ry: spec.legW.bottom * 0.95, angle: 0), pawColor, group)
    }

    // MARK: Body

    mutating func torso() {
        let c = body(spec.bodyC)
        let rx = spec.bodyR.x, ry = spec.bodyR.y
        switch species {
        case .sheep:
            // A cloud of wool puffs; each one gets its own shading so the fleece looks lumpy.
            add(.ellipse(c: c, rx: rx - 2, ry: ry - 1.5, angle: bodyAngle), spec.fur, G.body, volume: 0.6)
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi
                let pc = body(spec.bodyC + RigPoint(x: cos(a) * (rx - 4.5), y: sin(a) * (ry - 3.2)))
                let r = 4.6 + (k % 3 == 0 ? 0.7 : 0)
                add(.ellipse(c: pc, rx: r, ry: r, angle: 0), spec.fur, G.body)
            }
            for (dx, dy) in [(-5.0, -2.0), (2.0, -3.0), (6.0, 1.0), (-2.0, 2.5)] {
                add(.ellipse(c: body(spec.bodyC + RigPoint(x: dx, y: dy)), rx: 4.4, ry: 4.4, angle: 0), spec.fur, G.body)
            }
        case .bunny:
            add(.ellipse(c: c, rx: rx, ry: ry, angle: bodyAngle - 0.08), spec.fur, G.body)
            add(.ellipse(c: body(RigPoint(x: spec.hipX - 1, y: spec.bodyC.y + 2)), rx: 8.5, ry: 7.5, angle: 0), spec.fur, G.body)
            add(.ellipse(c: body(RigPoint(x: spec.bodyC.x + 3, y: spec.bodyC.y + ry * 0.55)), rx: rx * 0.7, ry: ry * 0.35, angle: bodyAngle),
                spec.belly, G.body, decal: true)
        default:
            add(.ellipse(c: c, rx: rx, ry: ry, angle: bodyAngle), spec.fur, G.body)
            // Chest bulge where the neck meets the body.
            add(.ellipse(c: body(RigPoint(x: spec.shoulderX + 2, y: spec.bodyC.y - 1)), rx: 6.5, ry: ry * 0.95, angle: bodyAngle),
                spec.fur, G.body)
            add(.ellipse(c: body(RigPoint(x: spec.bodyC.x + 2, y: spec.bodyC.y + ry * 0.62)), rx: rx * 0.78, ry: ry * 0.42, angle: bodyAngle),
                spec.belly, G.body, decal: true)
        }
        switch species {
        case .tiger:
            for (i, x) in [14.0, 18.5, 23.0, 27.5, 32.0].enumerated() {
                let top = body(RigPoint(x: x, y: spec.bodyC.y - spec.bodyR.y + 0.2))
                let lean = i % 2 == 0 ? 1.4 : 0.6
                add(.capsule(a: top, b: top + RigPoint(x: lean, y: 6.0), ra: 1.0, rb: 0.45), spec.dark, G.body, decal: true)
            }
            for x in [18.0, 33.0] {
                let low = body(RigPoint(x: x, y: spec.bodyC.y + spec.bodyR.y * 0.55))
                add(.capsule(a: low, b: low + RigPoint(x: -0.8, y: -3.2), ra: 0.8, rb: 0.4), spec.dark, G.body, decal: true)
            }
        case .cat:
            for (i, x) in [18.0, 23.5, 29.0].enumerated() {
                let top = body(RigPoint(x: x, y: spec.bodyC.y - spec.bodyR.y + 0.3))
                add(.capsule(a: top, b: top + RigPoint(x: 1.2 - Double(i) * 0.3, y: 4.2), ra: 1.1, rb: 0.6), spec.dark, G.body, decal: true)
            }
        case .dog:
            add(.ellipse(c: body(RigPoint(x: 25, y: spec.bodyC.y - 4.5)), rx: 9, ry: 5, angle: bodyAngle - 0.05), spec.dark, G.body, decal: true)
        case .redPanda:
            add(.ellipse(c: body(RigPoint(x: spec.bodyC.x - 1, y: spec.bodyC.y - spec.bodyR.y * 0.55)), rx: 9, ry: 1.6, angle: bodyAngle),
                spec.fur.shade(0.28), G.body, decal: true)
        case .flyingSquirrel:
            // The gliding flap: stretched out between the legs mid-air, folded along the side otherwise.
            let hip = body(RigPoint(x: spec.hipX, y: spec.bodyC.y)), shoulder = body(RigPoint(x: spec.shoulderX, y: spec.bodyC.y))
            if pose.mode == .standing && pose.swing[3] > 0.4 {
                let back = feet[1] + RigPoint(x: 0, y: -1.5), front = feet[3] + RigPoint(x: 0, y: -1.5)
                add(.triangle(hip, shoulder, front, round: 0.6), spec.fur.shade(-0.06), G.body)
                add(.triangle(hip, front, back, round: 0.6), spec.fur.shade(-0.06), G.body)
                add(.line([back, back * 0.5 + front * 0.5 + RigPoint(x: 0, y: -1.2), front], width: 0.8), spec.belly, G.body, decal: true)
            } else {
                let l = hip + RigPoint(x: -2, y: ry * 0.25), r = shoulder + RigPoint(x: 1, y: ry * 0.25)
                add(.line([l, (l + r) * 0.5 + RigPoint(x: 0, y: 1), r], width: 0.9), spec.dark, G.body, decal: true)
            }
        default:
            break
        }
    }

    // MARK: Tail

    mutating func tail() {
        let base = body(RigPoint(x: spec.bodyC.x - spec.bodyR.x + 2, y: spec.bodyC.y - spec.bodyR.y * 0.3))
        let a = pose.tailAngle
        func chain(_ offsets: [RigPoint]) -> [RigPoint] {
            offsets.map { (base + $0).rotated(a, around: base) }
        }
        switch species {
        case .sheep:
            add(.ellipse(c: (base + RigPoint(x: -1.5, y: -0.5)).rotated(a, around: base), rx: 3.6, ry: 3.2, angle: 0), spec.fur, G.tail)
        case .bunny:
            add(.ellipse(c: base + RigPoint(x: -0.5, y: 3), rx: 4.2, ry: 4, angle: 0), RGB(0xFFFFFF), G.tail)
        case .cat, .tiger:
            let pts = chain([RigPoint(x: 0, y: 0), RigPoint(x: -5, y: -3), RigPoint(x: -7.5, y: -9), RigPoint(x: -6.5, y: -15), RigPoint(x: -3.5, y: -18.5)])
            for (i, (u, v)) in zip(pts, pts.dropFirst()).enumerated() {
                let r1 = 2.3 - Double(i) * 0.15, r2 = 2.3 - Double(i + 1) * 0.15
                add(.capsule(a: u, b: v, ra: r1, rb: r2), i >= 3 && species == .cat ? spec.dark : spec.fur, G.tail)
                if species == .tiger {
                    // Thin dark bands across the tail.
                    let d = v - u, mid = u + d * 0.5
                    let across = RigPoint(x: -d.y, y: d.x) * ((r1 + 0.6) / max(d.length, 1e-6))
                    add(.capsule(a: mid + across, b: mid - across, ra: 0.7, rb: 0.7), spec.dark, G.tail, decal: true)
                } else if i == 1 || i == 2 {
                    add(.capsule(a: u + (v - u) * 0.45, b: u + (v - u) * 0.6, ra: r1 + 0.3, rb: r1 + 0.3), spec.dark, G.tail, decal: true)
                }
            }
            if species == .tiger { add(.ellipse(c: pts[4], rx: 2.0, ry: 2.0, angle: 0), spec.dark, G.tail) }
        case .dog:
            let pts = chain([RigPoint(x: 0, y: 0), RigPoint(x: -3.5, y: -5), RigPoint(x: -5, y: -11)])
            add(.capsule(a: pts[0], b: pts[1], ra: 2.3, rb: 1.9), spec.fur, G.tail)
            add(.capsule(a: pts[1], b: pts[2], ra: 1.9, rb: 1.4), spec.fur, G.tail)
            add(.ellipse(c: pts[2], rx: 1.7, ry: 1.9, angle: 0), spec.belly, G.tail)
        case .redPanda:
            // One big bushy tail arching up behind, with pale rings and a dark tip.
            let pts = chain([RigPoint(x: 1, y: 1), RigPoint(x: -3.5, y: 0), RigPoint(x: -7.5, y: -3), RigPoint(x: -9.5, y: -8), RigPoint(x: -10, y: -14), RigPoint(x: -8, y: -19)])
            let radii = [3.6, 4.2, 4.4, 4.3, 4.0, 3.3]
            for k in 0..<(pts.count - 1) {
                add(.capsule(a: pts[k], b: pts[k + 1], ra: radii[k], rb: radii[k + 1]), spec.fur, G.tail)
            }
            let ring = RGB(0xEDB680)
            for k in 1...3 {
                // A thin pale band across the tail at the middle of each segment.
                let d = pts[k + 1] - pts[k]
                let mid = pts[k] + d * 0.5
                let across = RigPoint(x: -d.y, y: d.x) * (1 / max(d.length, 1e-6))
                let r = (radii[k] + radii[k + 1]) / 2 + 1
                add(.capsule(a: mid + across * r, b: mid - across * r, ra: 1.25, rb: 1.25), ring, G.tail, decal: true)
            }
            let tipStart = pts[4] + (pts[5] - pts[4]) * 0.45
            add(.capsule(a: tipStart, b: pts[5] + (pts[5] - pts[4]) * 0.6, ra: 4.6, rb: 4.0), spec.dark, G.tail, decal: true)
        case .pig:
            // A little corkscrew.
            let pts = chain((0..<9).map { k in
                let a = Double(k) * 0.85
                return RigPoint(x: -2 - Double(k) * 0.35 - sin(a) * 1.8, y: -1 + cos(a) * 1.8 - 1.8)
            })
            for (u, v) in zip(pts, pts.dropFirst()) { add(.capsule(a: u, b: v, ra: 0.9, rb: 0.9), spec.fur.shade(-0.08), G.tail) }
        case .flyingSquirrel:
            // A flat, fluffy tail held out behind with a gentle upward curve.
            let pts = chain([RigPoint(x: 1, y: 1), RigPoint(x: -4, y: 0), RigPoint(x: -9, y: -2), RigPoint(x: -13, y: -6)])
            let radii = [2.6, 3.2, 3.3, 2.6]
            for k in 0..<(pts.count - 1) {
                add(.capsule(a: pts[k], b: pts[k + 1], ra: radii[k], rb: radii[k + 1]), spec.fur, G.tail)
            }
            add(.capsule(a: pts[2], b: pts[3], ra: 1.4, rb: 1.2), spec.dark, G.tail, decal: true)
        case .hippo, .elephant:
            // A short thin tail with a dark tuft.
            let pts = chain([RigPoint(x: 0, y: 0), RigPoint(x: -2.5, y: 3), RigPoint(x: -3, y: 7)])
            add(.capsule(a: pts[0], b: pts[1], ra: 1.1, rb: 0.8), spec.fur, G.tail)
            add(.capsule(a: pts[1], b: pts[2], ra: 0.8, rb: 0.7), spec.fur, G.tail)
            add(.ellipse(c: pts[2] + RigPoint(x: 0, y: 1), rx: 1.1, ry: 1.6, angle: 0), spec.dark.shade(-0.3), G.tail)
        }
    }

    // MARK: Head

    mutating func headParts() {
        let rx = spec.headR.x, ry = spec.headR.y
        let ear = pose.earAngle
        let white = RGB(0xFFFFFF)
        let pink = RGB(0xF29BAC)
        switch species {
        case .sheep:
            let face = spec.dark
            add(.ellipse(c: head(-6.5, -3.5), rx: 4.6, ry: 2.0, angle: -0.35 + ear), face.shade(-0.15), G.farEar)
            add(.ellipse(c: head(-6.2, -3.4), rx: 2.6, ry: 0.9, angle: -0.35 + ear), pink.shade(-0.2), G.farEar, decal: true)
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle + 0.25), face, G.head)
            add(.ellipse(c: head(3.4, 3.2), rx: 4.4, ry: 3.9, angle: headAngle + 0.2), face, G.head)
            add(.ellipse(c: head(4.2, 3.6), rx: 2.4, ry: 1.7, angle: headAngle), face.shade(0.18), G.head, decal: true)
            for (dx, dy, r) in [(-3.0, -6.0, 3.6), (0.6, -7.2, 3.6), (3.6, -5.8, 3.0), (-5.0, -3.2, 2.6)] {
                add(.ellipse(c: head(dx, dy), rx: r, ry: r, angle: 0), spec.fur, G.head)
            }
            add(.ellipse(c: head(-6.4, 0.4), rx: 4.0, ry: 1.9, angle: -0.3 - ear), face, G.nearEar)
            add(.ellipse(c: head(-6.9, 0.6), rx: 2.3, ry: 0.8, angle: -0.3 - ear), pink, G.nearEar, decal: true)
            eyes(near: head(2.4, -0.2), far: head(-1.6, -0.4), sclera: true)
            add(.ellipse(c: head(6.8, 2.6), rx: 0.7, ry: 0.5, angle: 0), RGB(0x1E181F), G.head, decal: true)
            mouth(at: head(5.5, 5.6), color: pink)
        case .cat:
            for (far, base) in [(true, -4.5), (false, 3.0)] {
                let tilt = (far ? -0.2 : 0.15) + ear * (far ? 1 : -1) * 0.6
                let a = head(base - 3.2, -4.5), tip = head(base + 0.2, -12.5), b = head(base + 3.4, -5.2)
                let pivotPoint = head(base, -5)
                let rot = { (p: RigPoint) in p.rotated(tilt, around: pivotPoint) }
                add(.triangle(rot(a), rot(tip), rot(b), round: 0.9), far ? spec.fur.shade(-0.2) : spec.fur, far ? G.farEar : G.head)
                let ia = head(base - 1.6, -5.6), itip = head(base + 0.2, -10.4), ib = head(base + 1.9, -5.9)
                add(.triangle(rot(ia), rot(itip), rot(ib), round: 0.4), far ? pink.shade(-0.3) : pink, far ? G.farEar : G.head, decal: true)
            }
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(-4.5, 3.8), rx: 3.6, ry: 2.6, angle: 0.3), spec.fur, G.head) // cheek fluff
            add(.ellipse(c: head(3.4, 3.4), rx: 4.6, ry: 3.2, angle: headAngle), spec.belly, G.head, decal: true)
            for dx in [-1.6, 0.4] {
                add(.capsule(a: head(dx, -7.0), b: head(dx + 0.3, -4.4), ra: 0.7, rb: 0.45), spec.dark, G.head, decal: true)
            }
            eyes(near: head(3.0, -1.0), far: head(-2.8, -1.2), sclera: false)
            add(.triangle(head(5.4, 1.4), head(7.4, 1.4), head(6.4, 2.7), round: 0.3), pink.shade(-0.1), G.head, decal: true)
            mouth(at: head(6.2, 4.0), color: pink.shade(-0.3))
            for (dy, ang) in [(2.6, -0.15), (3.8, 0.12)] {
                let s = head(8.0, dy)
                add(.line([s, s + RigPoint(x: 4.5, y: ang * 4.5)], width: 0.45), RGB(0xFFFFFF, alpha: 0.9), G.fx, decal: true)
            }
            blush(head(1.0, 2.6))
        case .dog:
            let earC = spec.dark
            add(.ellipse(c: head(-4.6, 1.5), rx: 3.4, ry: 7.2, angle: 0.25 + ear * 0.5), earC.shade(-0.15), G.farEar)
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(4.2, 3.6), rx: 5.0, ry: 3.8, angle: headAngle + 0.1), spec.belly, G.head)
            add(.capsule(a: head(1.2, -7.4), b: head(2.6, 0.5), ra: 1.2, rb: 2.2), spec.belly, G.head, decal: true) // blaze
            add(.ellipse(c: head(-4.0, 3.2), rx: 2.9, ry: 6.2, angle: 0.18 + ear * 0.6), earC, G.nearEar)
            eyes(near: head(3.2, -1.6), far: head(-0.6, -1.9), sclera: false)
            add(.ellipse(c: head(8.6, 1.9), rx: 1.5, ry: 1.1, angle: 0), RGB(0x241A1C), G.head, decal: true)
            mouth(at: head(7.2, 5.0), color: RGB(0x8E4A3E))
            if pose.mouthOpen { add(.ellipse(c: head(7.0, 7.0), rx: 1.2, ry: 1.8, angle: 0), pink, G.fx) }
            // Collar with a little tag.
            let n1 = head(-6.5, 5.5), n2 = head(-3.0, 8.5)
            add(.capsule(a: n1, b: n2, ra: 1.3, rb: 1.3), RGB(0xD9434E), G.head)
            add(.ellipse(c: n2 + RigPoint(x: 0.6, y: 1.6), rx: 1.1, ry: 1.1, angle: 0), RGB(0xF2C94C), G.head)
        case .bunny:
            for (far, base) in [(true, -2.6), (false, 1.2)] {
                let lean = (far ? -0.28 : 0.05) + ear * (far ? 1 : 0.6)
                let root = head(base, -5)
                let tip = (root + RigPoint(x: 0, y: -14)).rotated(lean, around: root)
                let mid = (root + RigPoint(x: 0, y: -7)).rotated(lean, around: root)
                let g = far ? G.farEar : G.head
                add(.capsule(a: root, b: mid, ra: 2.2, rb: 2.7), far ? spec.fur.shade(-0.18) : spec.fur, g)
                add(.capsule(a: mid, b: tip, ra: 2.7, rb: 1.9), far ? spec.fur.shade(-0.18) : spec.fur, g)
                add(.capsule(a: (root + mid) * 0.5, b: (mid + tip) * 0.5, ra: 1.0, rb: 1.2), pink, g, decal: true)
            }
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(3.6, 2.8), rx: 3.8, ry: 3.0, angle: headAngle), spec.belly, G.head, decal: true)
            eyes(near: head(2.4, -1.2), far: head(-2.4, -1.4), sclera: false)
            add(.ellipse(c: head(6.6, 1.3), rx: 1.0, ry: 0.75, angle: 0), pink.shade(-0.1), G.head, decal: true)
            mouth(at: head(6.1, 3.4), color: pink.shade(-0.3))
            blush(head(0.6, 2.4))
        case .redPanda:
            for (far, base) in [(true, -4.8), (false, 3.4)] {
                let tilt = (far ? -0.3 : 0.25) + ear * (far ? 1 : -1) * 0.5
                let a = head(base - 3.5, -4.0), tip = head(base, -10.5), b = head(base + 3.5, -4.4)
                let pivotPoint = head(base, -5)
                let rot = { (p: RigPoint) in p.rotated(tilt, around: pivotPoint) }
                add(.triangle(rot(a), rot(tip), rot(b), round: 1.6), white, far ? G.farEar : G.head)
                add(.triangle(rot(head(base - 1.3, -5.2)), rot(head(base, -8.0)), rot(head(base + 1.3, -5.4)), round: 0.5),
                    spec.fur.shade(-0.45), far ? G.farEar : G.head, decal: true)
            }
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(3.8, 3.4), rx: 5.0, ry: 3.4, angle: headAngle), white, G.head, decal: true)
            add(.ellipse(c: head(3.6, -4.4), rx: 1.4, ry: 0.8, angle: -0.2), white, G.head, decal: true)
            add(.ellipse(c: head(-2.2, -4.6), rx: 1.2, ry: 0.75, angle: 0.2), white, G.head, decal: true)
            for (dx, lean) in [(3.0, 0.5), (-2.4, -0.3)] {
                add(.capsule(a: head(dx, 1.0), b: head(dx + lean, 3.6), ra: 0.75, rb: 0.45), spec.fur.shade(-0.5), G.head, decal: true)
            }
            eyes(near: head(3.0, -0.8), far: head(-2.4, -1.0), sclera: false)
            add(.ellipse(c: head(8.2, 2.0), rx: 1.3, ry: 0.95, angle: 0), RGB(0x241A1C), G.head, decal: true)
            mouth(at: head(7.0, 4.6), color: RGB(0x7A3B30))
        case .pig:
            // Floppy triangle ears tipping forward, and a round snout with two nostrils.
            for far in [true, false] {
                let base = far ? -4.6 : -1.6
                let flop = (far ? -0.15 : 0.1) - ear * 0.6
                let pivotPoint = head(base, -6)
                let rot = { (p: RigPoint) in p.rotated(flop, around: pivotPoint) }
                let a = head(base - 2.6, -5.4), tip = head(base + 3.2, -12.0), b = head(base + 2.6, -6.6)
                add(.triangle(rot(a), rot(tip), rot(b), round: 0.8), far ? spec.fur.shade(-0.2) : spec.fur, G.farEar)
                if !far {
                    add(.triangle(rot(head(base - 0.8, -6.6)), rot(head(base + 2.2, -10.4)), rot(head(base + 1.4, -7.0)), round: 0.3),
                        spec.dark, G.farEar, decal: true)
                }
            }
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(9.2, 1.6), rx: 2.2, ry: 3.2, angle: headAngle + 0.1), spec.dark, G.head)
            pixels(["k.", "..", ".k"], centeredAt: head(10.0, 1.6))
            eyes(near: head(3.0, -0.8), far: head(-1.4, -1.0), sclera: false)
            mouth(at: head(5.4, 5.0), color: RGB(0x9A4A5C))
            blush(head(0.8, 2.4))
        case .hippo:
            // Big rounded muzzle, nostril bumps on top, tiny round ears.
            for (far, dx) in [(true, -3.6), (false, -0.8)] {
                let c = head(dx, -7.0 + (far ? 0.3 : 0))
                add(.ellipse(c: c, rx: 2.1, ry: 1.8, angle: ear), far ? spec.fur.shade(-0.2) : spec.fur, far ? G.farEar : G.nearEar)
                add(.ellipse(c: c + RigPoint(x: 0.2, y: 0.2), rx: 0.8, ry: 0.6, angle: 0), spec.belly.shade(-0.1), far ? G.farEar : G.nearEar, decal: true)
            }
            add(.ellipse(c: head(-1, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(5.6, 3.0), rx: 6.4, ry: 5.0, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(6.2, 6.0), rx: 5.0, ry: 2.0, angle: headAngle), spec.belly, G.head, decal: true)
            for dx in [7.2, 9.6] {
                add(.ellipse(c: head(dx, -1.2), rx: 1.2, ry: 0.8, angle: 0), spec.fur, G.head)
                add(.pixel(x: Int(head(dx, -1.2).x.rounded(.down)), y: Int(head(dx, -1.2).y.rounded(.down))), spec.dark.shade(-0.35), G.head, decal: true)
            }
            eyes(near: head(1.8, -2.2), far: head(-2.2, -2.4), sclera: false)
            mouth(at: head(9.2, 5.2), color: spec.dark.shade(-0.2))
            blush(head(3.6, 2.6))
        case .elephant:
            // A big floppy ear over the side of the head and a trunk that curls (up when calling).
            add(.ellipse(c: head(-3.2, -2.0), rx: 5.5, ry: 7.2, angle: -0.2 + ear * 0.5), spec.dark, G.farEar)
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            let lifted = pose.mouthOpen
            let trunk = lifted
                ? [head(6.2, 1.5), head(9.6, -0.5), head(12.2, -4.5), head(13.4, -9.0), head(15.2, -10.6)]
                : [head(6.2, 1.5), head(9.0, 4.4), head(9.8, 8.4), head(9.4, 12.0), head(11.0, 13.6)]
            let radii = [3.2, 2.5, 2.0, 1.6, 1.3]
            for k in 0..<(trunk.count - 1) {
                var a = trunk[k], b = trunk[k + 1]
                a.y = min(a.y, ground - radii[k]); b.y = min(b.y, ground - radii[k + 1])
                add(.capsule(a: a, b: b, ra: radii[k], rb: radii[k + 1]), spec.fur, G.head)
            }
            add(.ellipse(c: head(-5.0, 1.6), rx: 4.8, ry: 6.6, angle: 0.1 + ear * 0.6), spec.fur.shade(-0.05), G.nearEar)
            add(.ellipse(c: head(-4.8, 1.8), rx: 2.9, ry: 4.4, angle: 0.1 + ear * 0.6), RGB(0xE8A9B8), G.nearEar, decal: true)
            eyes(near: head(3.4, -2.0), far: head(0.2, -2.2), sclera: false)
            mouth(at: head(4.4, 6.0), color: spec.dark.shade(-0.2))
            blush(head(2.4, 2.6))
        case .flyingSquirrel:
            // Rounded ears, a pale face and the big dark eyes of a night glider.
            for (far, dx) in [(true, -3.6), (false, -0.6)] {
                let c = head(dx, -6.2)
                add(.ellipse(c: c, rx: 2.0, ry: 2.6, angle: -0.2 + ear), far ? spec.fur.shade(-0.2) : spec.fur, far ? G.farEar : G.head)
                if !far { add(.ellipse(c: c + RigPoint(x: 0.2, y: 0.4), rx: 1.0, ry: 1.5, angle: -0.2 + ear), RGB(0xE8B7AE), G.head, decal: true) }
            }
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(3.4, 3.2), rx: 4.4, ry: 3.0, angle: headAngle), spec.belly, G.head, decal: true)
            if pose.eyes == .open {
                for p in [head(-1.8, -1.2), head(2.8, -1.0)] { pixels(["kkw", "kkk", "kkk"], centeredAt: p) }
            } else {
                eyes(near: head(2.6, -1.0), far: head(-2.0, -1.2), sclera: false)
            }
            add(.ellipse(c: head(7.0, 1.4), rx: 0.9, ry: 0.7, angle: 0), RGB(0x3A2A2A), G.head, decal: true)
            mouth(at: head(5.8, 3.6), color: spec.dark)
            blush(head(0.6, 2.6))
        case .tiger:
            // Round ears with dark backs, white cheeks and brows, stripes on the forehead and cheeks.
            for (far, dx) in [(true, -4.4), (false, 0.6)] {
                let c = head(dx, -6.6)
                add(.ellipse(c: c, rx: 2.6, ry: 2.4, angle: ear), far ? spec.fur.shade(-0.2) : spec.fur, far ? G.farEar : G.head)
                add(.ellipse(c: c + RigPoint(x: 0.2, y: 0.4), rx: 1.3, ry: 1.1, angle: ear), far ? spec.dark : spec.belly, far ? G.farEar : G.head, decal: true)
            }
            add(.ellipse(c: head(0, 0), rx: rx, ry: ry, angle: headAngle), spec.fur, G.head)
            add(.ellipse(c: head(-4.8, 3.6), rx: 3.6, ry: 2.8, angle: 0.3), spec.belly, G.head) // cheek ruff
            add(.ellipse(c: head(4.0, 3.6), rx: 4.8, ry: 3.4, angle: headAngle), spec.belly, G.head, decal: true)
            for (dx, top) in [(-2.0, -7.4), (0.0, -7.6), (2.0, -7.2)] {
                add(.capsule(a: head(dx, top), b: head(dx + 0.2, top + 2.6), ra: 0.7, rb: 0.4), spec.dark, G.head, decal: true)
            }
            add(.ellipse(c: head(3.0, -3.6), rx: 1.4, ry: 0.6, angle: -0.2), spec.belly, G.head, decal: true)
            eyes(near: head(3.0, -1.6), far: head(-2.4, -1.8), sclera: false)
            add(.triangle(head(6.6, 1.2), head(8.8, 1.2), head(7.7, 2.6), round: 0.3), RGB(0xD9707E), G.head, decal: true)
            if pose.mouthOpen {
                // A big toothy roar.
                add(.ellipse(c: head(6.8, 5.2), rx: 2.2, ry: 1.9, angle: 0), RGB(0x7A2A34), G.head, decal: true)
                add(.triangle(head(5.4, 3.8), head(6.4, 3.8), head(5.9, 5.0), round: 0.1), RGB(0xFFFFFF), G.head, decal: true)
                add(.triangle(head(7.4, 3.8), head(8.4, 3.8), head(7.9, 5.0), round: 0.1), RGB(0xFFFFFF), G.head, decal: true)
            } else {
                mouth(at: head(7.4, 4.4), color: spec.dark)
            }
            for (dy, ang) in [(2.6, -0.15), (3.8, 0.12)] {
                let s = head(9.0, dy)
                add(.line([s, s + RigPoint(x: 4.5, y: ang * 4.5)], width: 0.45), RGB(0xFFFFFF, alpha: 0.9), G.fx, decal: true)
            }
        }
    }

    /// Eyes are hand-placed pixel stamps snapped to the grid, so they stay crisp and
    /// symmetric at 64x64 instead of rasterizing into uneven blobs.
    /// `k` = pupil, `w` = white (shine or sclera), `.` = untouched.
    mutating func eyes(near: RigPoint, far: RigPoint, sclera: Bool) {
        let stamp: [String]
        switch pose.eyes {
        case .open: stamp = sclera ? ["ww", "wk", "wk"] : ["kw", "kk", "kk"]
        case .wide: stamp = ["www", "wkw", "www"]
        case .closed: stamp = ["k.k", ".k."]
        case .happy: stamp = [".k.", "k.k"]
        }
        for p in [far, near] { pixels(stamp, centeredAt: p) }
    }

    mutating func pixels(_ rows: [String], centeredAt p: RigPoint) {
        let w = rows.map(\.count).max() ?? 0
        let x0 = Int((p.x - Double(w) / 2).rounded()), y0 = Int((p.y - Double(rows.count) / 2).rounded())
        for (dy, row) in rows.enumerated() {
            for (dx, ch) in row.enumerated() where ch != "." {
                add(.pixel(x: x0 + dx, y: y0 + dy), ch == "w" ? RGB(0xFFFFFF) : spec.eye, G.head, decal: true)
            }
        }
    }

    mutating func mouth(at p: RigPoint, color: RGB) {
        if pose.mouthOpen {
            add(.ellipse(c: p + RigPoint(x: 0, y: 0.6), rx: 1.3, ry: 1.4, angle: 0), RGB(0x8C3B46), G.head, decal: true)
            add(.ellipse(c: p + RigPoint(x: 0, y: 1.2), rx: 0.8, ry: 0.6, angle: 0), RGB(0xF29BAC), G.head, decal: true)
        } else {
            add(.line([p + RigPoint(x: -1.2, y: -0.2), p + RigPoint(x: -0.4, y: 0.4), p + RigPoint(x: 0.2, y: -0.1)], width: 0.5), color, G.head, decal: true)
        }
    }

    mutating func blush(_ p: RigPoint) {
        add(.ellipse(c: p, rx: 1.7, ry: 0.9, angle: 0), RGB(0xF27C93, alpha: 0.55), G.head, decal: true, volume: 0)
    }

    // MARK: Effects

    mutating func effects() {
        let ink = RGB(0x3A3140)
        switch pose.extra {
        case .none:
            break
        case .zzz:
            let h = head(0, 0)
            let shown = pose.frame % 4 + 1, rise = Double(pose.frame % 2)
            for (i, (x, y, s)) in [(h.x + 4, h.y - 13 - rise, 1.5), (h.x + 8, h.y - 18 - rise, 1.9), (h.x + 12, h.y - 24 - rise, 2.4)].enumerated() where i < shown {
                let c = RGB(0x8FB4F2).shade(Double(i) * 0.1)
                add(.line([RigPoint(x: x - s, y: y - s), RigPoint(x: x + s, y: y - s), RigPoint(x: x - s, y: y + s), RigPoint(x: x + s, y: y + s)], width: 0.9), c, G.fx, decal: true)
            }
        case .call:
            let m = head(spec.headR.x + 2, 3)
            for (i, r) in [2.4, 4.4, 6.4].enumerated() where i <= pose.frame {
                let pts = (0...6).map { k -> RigPoint in
                    let a = -0.7 + Double(k) / 6 * 1.4
                    return m + RigPoint(x: cos(a) * r, y: sin(a) * r)
                }
                add(.line(pts, width: 0.9 - Double(i) * 0.1), ink.with(alpha: 1 - Double(i) * 0.2), G.fx, decal: true)
            }
        case .food where pose.seasonal == .pumpkin:
            pumpkin(at: RigPoint(x: head(4, 7).x + 1, y: ground - 2.4), size: 0.7)
        case .food:
            let x = head(4, 7).x
            switch species {
            case .sheep, .redPanda:
                for (i, dx) in [-3.0, -1.5, 0.0, 1.6, 3.2, 4.6].enumerated() {
                    let h = [3.5, 5.5, 4.5, 6.0, 3.8, 4.8][i]
                    let base = RigPoint(x: x + dx, y: ground)
                    let color = species == .redPanda ? RGB(0x6DBE5A) : (i % 2 == 0 ? RGB(0x5DAE4A) : RGB(0x7FCB5E))
                    add(.line([base, base + RigPoint(x: (Double(i % 3) - 1) * 0.8, y: -h)], width: 1.1), color, G.fx, decal: true)
                }
            case .cat:
                add(.ellipse(c: RigPoint(x: x + 1, y: ground - 1.6), rx: 4, ry: 1.7, angle: 0), RGB(0x86BEDF), G.fx)
                add(.triangle(RigPoint(x: x - 3, y: ground - 1.6), RigPoint(x: x - 5.5, y: ground - 3.6), RigPoint(x: x - 5.5, y: ground + 0.4), round: 0.3), RGB(0x86BEDF), G.fx)
                add(.ellipse(c: RigPoint(x: x + 3.2, y: ground - 2), rx: 0.5, ry: 0.5, angle: 0), ink, G.fx, decal: true)
            case .dog:
                add(.capsule(a: RigPoint(x: x - 3, y: ground - 1.5), b: RigPoint(x: x + 3, y: ground - 1.5), ra: 0.9, rb: 0.9), RGB(0xF4EAD6), G.fx)
                for dx in [-3.4, 3.4] { for dy in [-0.9, 0.9] {
                    add(.ellipse(c: RigPoint(x: x + dx, y: ground - 1.5 + dy), rx: 1.1, ry: 1.1, angle: 0), RGB(0xF4EAD6), G.fx)
                } }
            case .bunny:
                add(.capsule(a: RigPoint(x: x - 3.5, y: ground - 1.6), b: RigPoint(x: x + 3, y: ground - 1.2), ra: 1.6, rb: 0.6), RGB(0xF08A2B), G.fx)
                for a in [-0.5, 0.0, 0.5] {
                    let s = RigPoint(x: x - 3.8, y: ground - 1.8)
                    add(.line([s, s + RigPoint(x: -3 * cos(a), y: -3 * sin(a) - 1)], width: 0.8), RGB(0x5DAE4A), G.fx, decal: true)
                }
            case .pig:
                let c = RigPoint(x: x + 1, y: ground - 2.4)
                add(.ellipse(c: c, rx: 2.6, ry: 2.4, angle: 0), RGB(0xD8343F), G.fx)
                add(.capsule(a: c + RigPoint(x: 0, y: -2.2), b: c + RigPoint(x: 0.5, y: -3.6), ra: 0.4, rb: 0.35), RGB(0x6B4226), G.fx)
                add(.ellipse(c: c + RigPoint(x: 1.6, y: -3.2), rx: 1.2, ry: 0.6, angle: -0.4), RGB(0x5DAE4A), G.fx)
            case .hippo:
                // A slice of watermelon: green rind, red flesh, dark seeds.
                let c = RigPoint(x: x + 1, y: ground - 0.4)
                add(.triangle(c + RigPoint(x: -4, y: 0), c + RigPoint(x: 4, y: 0), c + RigPoint(x: 0, y: -4.6), round: 0.6), RGB(0xE84A5A), G.fx)
                add(.capsule(a: c + RigPoint(x: -4, y: -0.3), b: c + RigPoint(x: 4, y: -0.3), ra: 0.8, rb: 0.8), RGB(0x4E9A3A), G.fx)
                for (dx, dy) in [(-1.5, -1.8), (1.2, -1.6), (0, -3.0)] {
                    add(.pixel(x: Int((c.x + dx).rounded(.down)), y: Int((c.y + dy).rounded(.down))), RGB(0x2A1E20), G.fx, decal: true)
                }
            case .tiger:
                // A drumstick: meaty end and a bone handle.
                add(.capsule(a: RigPoint(x: x - 3.5, y: ground - 1.3), b: RigPoint(x: x + 0.5, y: ground - 1.3), ra: 0.6, rb: 0.6), RGB(0xF4EAD6), G.fx)
                add(.ellipse(c: RigPoint(x: x - 4, y: ground - 1.3), rx: 1.0, ry: 1.0, angle: 0), RGB(0xF4EAD6), G.fx)
                add(.ellipse(c: RigPoint(x: x + 2.4, y: ground - 2.0), rx: 3.0, ry: 2.2, angle: -0.2), RGB(0xB5562C), G.fx)
            case .flyingSquirrel:
                let c = RigPoint(x: x + 1, y: ground - 2.2)
                add(.ellipse(c: c, rx: 1.8, ry: 2.2, angle: 0), RGB(0xC08A4A), G.fx)
                add(.ellipse(c: c + RigPoint(x: 0, y: -1.8), rx: 2.2, ry: 1.0, angle: 0), RGB(0x7A5030), G.fx)
                add(.capsule(a: c + RigPoint(x: 0, y: -2.6), b: c + RigPoint(x: 0.4, y: -3.6), ra: 0.35, rb: 0.3), RGB(0x5A3A22), G.fx)
            case .elephant:
                for (dx, a) in [(-2.5, 0.3), (2.0, -0.2)] {
                    let c = RigPoint(x: x + dx, y: ground - 1.2)
                    let d = RigPoint(x: cos(a) * 1.5, y: sin(a) * 1.5)
                    add(.capsule(a: c - d, b: c + d, ra: 1.1, rb: 1.1), RGB(0xD6A86A), G.fx)
                    add(.ellipse(c: c, rx: 0.7, ry: 0.9, angle: a), RGB(0xD6A86A).shade(-0.15), G.fx)
                }
            }
        }
    }
}

/// Where the head sits in a pose (for preview crops).
public func buildHeadCenter(_ species: Animal, _ pose: RigPose) -> RigPoint {
    var b = Builder(species: species, spec: spec(species), pose: pose)
    b.build()
    return b.headCenter
}
