/// Art for the furry animals (cat, dog, bunny, red panda): a side-view body with a
/// front-facing head, drawn from small character templates plus simple shapes.
extension PetArt {
    enum Tail { case curl, wag, cotton, ringed }

    struct Critter {
        var fur: UInt8
        var dark: UInt8
        var light: UInt8
        var belly: UInt8
        var legNear: UInt8
        var legFar: UInt8
        var paw: UInt8
        /// Body ellipse in body space.
        var body: (cx: Int, cy: Int, rx: Int, ry: Int)
        /// Top-left of the head template (before head offsets).
        var headAt: (x: Int, y: Int)
        var head: [String]
        /// Drawn behind the head, relative to `headAt` (e.g. floppy dog ears hang at the sides).
        var ears: [String]
        var earsAt: (x: Int, y: Int)
        /// Alternative ears when resting (nil: same as `ears`).
        var earsDown: [String]? = nil
        /// Top pixel of each eye, relative to `headAt`. Eyes are 2 pixels tall.
        var eyes: [(Int, Int)]
        /// Mouth position relative to `headAt`.
        var mouth: (Int, Int)
        var tail: Tail
    }

    static func critter(_ animal: Animal) -> Critter {
        switch animal {
        case .cat:
            return Critter(
                fur: 12, dark: 13, light: 14, belly: 14, legNear: 12, legFar: 13, paw: 14,
                body: (15, 22, 11, 4), headAt: (25, 12),
                head: [
                    "..FFFFFFF..",
                    ".FFFDFDFFF.",
                    "FFFFFFFFFFF",
                    "FFFFFFFFFFF",
                    "FFFFFPFFFFF",
                    ".FLLLLLLLF.",
                    "..FLLLLLF..",
                    "...FFFFF...",
                ],
                ears: [
                    ".D.......D.",
                    ".FD.....DF.",
                    ".FPF...FPF.",
                ],
                earsAt: (0, -3),
                eyes: [(2, 2), (8, 2)], mouth: (5, 5), tail: .curl
            )
        case .dog:
            return Critter(
                fur: 15, dark: 16, light: 14, belly: 14, legNear: 15, legFar: 16, paw: 14,
                body: (15, 21, 11, 5), headAt: (25, 11),
                head: [
                    "...FFFFF...",
                    "..FFFFFFF..",
                    ".FFFFFFFFF.",
                    ".FFFFFFFFF.",
                    ".FFLLLLLFF.",
                    "..LLLNLLL..",
                    "..LLLLLLL..",
                    "...LLLLL...",
                ],
                ears: [
                    "DDD.......DDD",
                    "DDD.......DDD",
                    "DD.........DD",
                    "DD.........DD",
                    "D...........D",
                ],
                earsAt: (-1, 1),
                eyes: [(3, 2), (7, 2)], mouth: (5, 6), tail: .wag
            )
        case .bunny:
            return Critter(
                fur: 17, dark: 18, light: 14, belly: 14, legNear: 17, legFar: 18, paw: 14,
                body: (14, 24, 10, 5), headAt: (25, 15),
                head: [
                    "..FFFFF..",
                    ".FFFFFFF.",
                    "FFFFFFFFF",
                    "FFFFFFFFF",
                    "FFFFPFFFF",
                    ".FLLLLLF.",
                    "..FFFFF..",
                ],
                ears: [
                    "..FF.FF..",
                    "..FP.PF..",
                    "..FP.PF..",
                    "..FP.PF..",
                    "..FP.PF..",
                    "..FF.FF..",
                    "..FF.FF..",
                ],
                earsAt: (0, -7),
                earsDown: [
                    ".........",
                    "FF...FF..",
                    "FPF..PF..",
                    ".FPF.PF..",
                    "..FP.PF..",
                    "..FF.FF..",
                    "..FF.FF..",
                ],
                eyes: [(2, 2), (6, 2)], mouth: (4, 5), tail: .cotton
            )
        case .redPanda, .sheep:
            return Critter(
                fur: 19, dark: 20, light: 14, belly: 20, legNear: 20, legFar: 20, paw: 20,
                body: (15, 21, 11, 5), headAt: (25, 11),
                head: [
                    "..FFFFFFF..",
                    ".FFFFFFFFF.",
                    "FFLLFFFLLFF",
                    "FFFFFFFFFFF",
                    "FFFFFFFFFFF",
                    "FLDLLNLLDLF",
                    ".LLLLLLLLL.",
                    "..LLLLLLL..",
                ],
                ears: [
                    ".LL.....LL.",
                    ".LDL...LDL.",
                ],
                earsAt: (0, -2),
                eyes: [(3, 3), (7, 3)], mouth: (5, 6), tail: .ringed
            )
        }
    }

    static func renderCritter(_ c: inout PixelCanvas, _ pose: Pose, _ animal: Animal) {
        let k = critter(animal)
        let by = pose.bodyDY
        let hx = pose.headDX + 2, hy = pose.headDY
        let headX = k.headAt.x + hx, headY = k.headAt.y + hy
        let colors: [Character: UInt8] = ["F": k.fur, "D": k.dark, "L": k.light, "P": 6, "N": 1, "W": 2]

        drawTail(&c, k, pose, bodyDY: by)
        if animal == .bunny {
            drawBunnyLegs(&c, k, pose, bodyDY: by)
        } else if pose.legs != .folded {
            drawLegs(&c, pose.legs, bodyDY: by, near: k.legNear, far: k.legFar, paw: k.paw)
        }

        // Body with a lighter (or darker) belly, plus a neck joining the head.
        let b = k.body
        c.ellipse(cx: b.cx, cy: b.cy + by, rx: b.rx, ry: b.ry, k.fur)
        for y in (b.cy + by + 2)...(b.cy + by + b.ry) {
            for x in (b.cx - b.rx + 3)...(b.cx + b.rx - 2) where c[x, y] == k.fur { c[x, y] = k.belly }
        }
        c.ellipse(cx: b.cx + b.rx - 2, cy: b.cy + by - 2 + min(hy, 4) / 2, rx: 3, ry: 3, k.fur)
        drawMarkings(&c, animal, k, bodyDY: by)

        // Ears behind the head, then the head.
        let ears = (!pose.earUp ? k.earsDown : nil) ?? k.ears
        let earLift = pose.earUp && k.earsDown == nil ? -1 : 0
        stamp(&c, ears, x: headX + k.earsAt.x, y: headY + k.earsAt.y + earLift, colors)
        if earLift != 0, let last = ears.last { stamp(&c, [last], x: headX + k.earsAt.x, y: headY + k.earsAt.y + ears.count - 1, colors) }
        stamp(&c, k.head, x: headX, y: headY, colors)
        if pose.legs == .folded && animal != .bunny {
            drawLegs(&c, .folded, bodyDY: by, near: k.legNear, far: k.legFar, paw: k.paw)
        }

        outlineAll(&c)

        // Face details on top of the outline.
        for (ex, ey) in k.eyes { drawCritterEye(&c, pose.eyes, x: headX + ex, y: headY + ey, lid: k.dark) }
        let (mx, my) = (headX + k.mouth.0, headY + k.mouth.1)
        if pose.mouthOpen {
            c[mx, my + 1] = 6
            if animal == .dog { c[mx, my + 2] = 6 } // tongue
        }
        if animal == .cat {
            let right = headX + k.head[0].count
            c.plot([(right, headY + 4), (right + 1, headY + 3), (right, headY + 5), (right + 1, headY + 6)], 14)
        }
        if animal == .dog { c.fill(x: headX - 1, y: headY + 6, width: 2, height: 2, 21) } // collar on the neck

        drawEffect(&c, pose.effect, animal: animal,
                   callX: headX + k.head[0].count + 1, callY: my, foodX: headX + 4)
    }

    /// Stamps a character template; '.' is transparent.
    static func stamp(_ c: inout PixelCanvas, _ rows: [String], x: Int, y: Int, _ colors: [Character: UInt8]) {
        for (dy, row) in rows.enumerated() {
            for (dx, ch) in row.enumerated() {
                if let color = colors[ch] { c[x + dx, y + dy] = color }
            }
        }
    }

    private static func drawCritterEye(_ c: inout PixelCanvas, _ eyes: Pose.Eyes, x: Int, y: Int, lid: UInt8) {
        switch eyes {
        case .open:
            c.plot([(x, y), (x, y + 1)], 1)
        case .wide:
            c.plot([(x, y), (x, y + 1), (x + 1, y + 1)], 1)
            c[x + 1, y] = 5
        case .closed:
            c.plot([(x - 1, y + 1), (x, y + 1), (x + 1, y + 1)], lid)
        case .happy:
            c.plot([(x - 1, y + 1), (x, y), (x + 1, y + 1)], 1)
        }
    }

    private static func drawTail(_ c: inout PixelCanvas, _ k: Critter, _ pose: Pose, bodyDY by: Int) {
        let wag = pose.tailDY
        let baseX = k.body.cx - k.body.rx + 1, baseY = k.body.cy + by - 1
        switch k.tail {
        case .curl:
            let points = [(0, 0), (-2, -1), (-3, -3), (-3 + wag, -5), (-2 + wag, -7), (-1 + wag * 2, -8)]
            for (i, p) in points.enumerated() {
                c.fill(x: baseX + p.0, y: baseY + p.1, width: 2, height: 2, i >= 4 ? k.dark : k.fur)
            }
        case .wag:
            let points = [(0, 0), (-1, -2), (-2 + wag, -4), (-2 + wag * 2, -5)]
            for p in points { c.fill(x: baseX + p.0, y: baseY + p.1, width: 2, height: 2, k.fur) }
        case .cotton:
            c.disc(cx: baseX - 1, cy: baseY + wag, r: 2, 2)
        case .ringed:
            let points = [(0, 1), (-2, 0), (-4, -1), (-5, -3 + wag), (-5, -5 + wag), (-4, -7 + wag)]
            for (i, p) in points.enumerated() {
                let color: UInt8 = i == points.count - 1 ? k.dark : (i % 2 == 0 ? k.fur : 25)
                c.disc(cx: baseX + p.0, cy: baseY + p.1, r: 2, color)
            }
        }
    }

    /// Bunnies have big back feet and small front paws; legs stretch out mid-hop.
    private static func drawBunnyLegs(_ c: inout PixelCanvas, _ k: Critter, _ pose: Pose, bodyDY by: Int) {
        if pose.lift > 0 {
            c.fill(x: 2, y: ground - 3, width: 6, height: 2, k.fur)   // back feet kicked out
            c.fill(x: 2, y: ground - 2, width: 2, height: 1, k.paw)
            c.fill(x: 22, y: ground - 2, width: 2, height: 3, k.fur)  // front paws reaching
            c.fill(x: 24, y: ground - 1, width: 2, height: 2, k.legFar)
        } else if pose.legs == .folded {
            c.fill(x: 6, y: ground - 1, width: 7, height: 2, k.fur)
            c.fill(x: 20, y: ground - 1, width: 4, height: 2, k.paw)
        } else {
            c.fill(x: 5, y: ground - 1, width: 8, height: 2, k.fur)
            c.fill(x: 5, y: ground, width: 3, height: 1, k.paw)
            c.fill(x: 20, y: 27 + by, width: 2, height: 5 - by, k.legFar)
            c.fill(x: 23, y: 27 + by, width: 2, height: 5 - by, k.fur)
            c.fill(x: 23, y: ground, width: 2, height: 1, k.paw)
        }
    }

    private static func drawMarkings(_ c: inout PixelCanvas, _ animal: Animal, _ k: Critter, bodyDY by: Int) {
        let top = k.body.cy + by - k.body.ry
        switch animal {
        case .cat:
            for x in [9, 13, 17] { c.fill(x: x, y: top, width: 1, height: 3, k.dark) }
        case .dog:
            c.ellipse(cx: 11, cy: top + 2, rx: 3, ry: 1, k.dark)
        case .redPanda:
            c.fill(x: k.body.cx - 6, y: top + 1, width: 10, height: 1, 25) // lighter back stripe
        default:
            break
        }
    }

    /// Outlines every solid pixel where it meets transparency or the ground shadow.
    private static func outlineAll(_ c: inout PixelCanvas) {
        let source = c
        for y in 0..<height {
            for x in 0..<width where source.pixel(x, y) == 0 || source.pixel(x, y) == 10 {
                let neighbors = [source.pixel(x - 1, y), source.pixel(x + 1, y), source.pixel(x, y - 1), source.pixel(x, y + 1)]
                if neighbors.contains(where: { $0 != 0 && $0 != 1 && $0 != 10 }) { c.pixels[y * width + x] = 1 }
            }
        }
    }

    // MARK: Calls and food

    static func drawCall(_ c: inout PixelCanvas, _ animal: Animal, frame: Int, x: Int, y: Int) {
        switch animal {
        case .cat:
            // Wavy "meow" lines.
            for i in 0...min(frame, 1) {
                let yy = y - 3 + i * 4
                c.plot([(x, yy + 1), (x + 1, yy), (x + 2, yy + 1), (x + 3, yy)], 1)
            }
        case .dog:
            // A burst of short lines.
            let len = frame + 1
            for i in 0..<len {
                c.plot([(x + 1 + i, y - 1 - i), (x + 1 + i, y + 1), (x + 1 + i, y + 3 + i)], 1)
            }
        case .bunny:
            // A little heart that floats up.
            let hy = y - 3 - frame
            c.plot([(x, hy), (x + 2, hy), (x - 1, hy + 1), (x, hy + 1), (x + 1, hy + 1), (x + 2, hy + 1),
                    (x + 3, hy + 1), (x, hy + 2), (x + 1, hy + 2), (x + 2, hy + 2), (x + 1, hy + 3)], 6)
        case .redPanda:
            // Sparkles.
            for (i, (dx, dy)) in [(1, -3), (3, 1), (2, -7)].enumerated() where i <= frame {
                c.plot([(x + dx, y + dy), (x + dx - 1, y + dy + 1), (x + dx + 1, y + dy + 1), (x + dx, y + dy + 2)], 9)
                c[x + dx, y + dy + 1] = 5
            }
        case .sheep:
            break
        }
    }

    static func drawFood(_ c: inout PixelCanvas, _ animal: Animal, frame: Int, x: Int) {
        let g = ground
        let bitten = frame % 2 == 1
        switch animal {
        case .cat:
            // A small fish lying on the ground; loses its head bit by bit.
            c.fill(x: x + (bitten ? 2 : 1), y: g - 1, width: bitten ? 3 : 5, height: 2, 23)
            c.plot([(x + 6, g - 2), (x + 6, g), (x + 7, g - 2), (x + 7, g), (x + 6, g - 1)], 23)
            if !bitten { c[x + 2, g - 1] = 1 }
        case .dog:
            c.fill(x: x + 1, y: g - 1, width: 6, height: 1, 24)
            c.plot([(x, g - 2), (x, g), (x + 7, g - 2), (x + 7, g), (x + 1, g - 2), (x + 6, g)], 24)
            c.plot([(x + 1, g), (x + 6, g - 2)], 24)
        case .bunny:
            let len = bitten ? 4 : 6
            c.fill(x: x + 1, y: g - 1, width: len, height: 2, 22)
            c[x + len + 1, g] = 22
            c.plot([(x + len + 2, g - 2), (x + len + 3, g - 1), (x + len + 2, g), (x + len + 3, g - 3)], 7)
        case .redPanda:
            for y in (g - 7)...g { c[x + 3, y] = (y - g) % 3 == 0 ? 8 : 7 }
            c.plot([(x + 4, g - 6), (x + 5, g - 7), (x + 2, g - 4), (x + 1, g - 5), (x + 4, g - 2), (x + 5, g - 3)], 8)
            if !bitten { c.plot([(x + 6, g - 8), (x, g - 6)], 7) }
        case .sheep:
            break
        }
    }
}
