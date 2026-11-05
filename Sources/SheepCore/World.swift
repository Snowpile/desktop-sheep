/// A rectangle in global screen coordinates, AppKit-style (origin bottom-left, y grows upward).
public struct Rect: Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.minX = x
        self.minY = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }

    public func contains(x: Double, y: Double) -> Bool {
        x >= minX && x <= maxX && y >= minY && y <= maxY
    }
}

/// A horizontal surface the sheep can stand on: a screen floor or the top edge of a window.
public struct Platform: Equatable, Sendable {
    public var y: Double
    public var minX: Double
    public var maxX: Double
    public var isFloor: Bool

    public init(y: Double, minX: Double, maxX: Double, isFloor: Bool = false) {
        self.y = y
        self.minX = minX
        self.maxX = maxX
        self.isFloor = isFloor
    }

    public func spans(_ x: Double) -> Bool { x >= minX && x <= maxX }
}

/// Everything the simulation needs to know about the desktop.
public struct World: Sendable {
    /// Usable area of each display (excludes the menu bar and Dock).
    public var screens: [Rect]
    /// Window top edges (screen floors are derived from `screens`).
    public var windowTops: [Platform]
    /// Window frames, front to back (pets can climb their sides).
    public var windows: [Rect]
    /// Temporary surfaces such as other pets' backs.
    public var extraPlatforms: [Platform] = []

    public init(screens: [Rect], windowTops: [Platform] = [], windows: [Rect] = []) {
        self.screens = screens
        self.windowTops = windowTops
        self.windows = windows
    }

    /// Screen floors plus window tops.
    public var platforms: [Platform] {
        screens.map { Platform(y: $0.minY, minX: $0.minX, maxX: $0.maxX, isFloor: true) } + windowTops + extraPlatforms
    }

    /// The screen containing the point, if any.
    public func screen(containingX x: Double, y: Double) -> Rect? {
        screens.first { $0.contains(x: x, y: y) }
    }

    /// The highest platform at `x` whose surface is at or below `y` (within `tolerance`).
    public func platform(under x: Double, atOrBelow y: Double, tolerance: Double = 0.5) -> Platform? {
        platforms
            .filter { $0.spans(x) && $0.y <= y + tolerance }
            .max { $0.y < $1.y }
    }

    /// A platform whose surface is within `tolerance` of the sheep's feet at `x`.
    public func support(x: Double, y: Double, tolerance: Double = 0.5) -> Platform? {
        platforms.first { $0.spans(x) && abs($0.y - y) <= tolerance }
    }

    /// Builds standable window-top segments from window frames ordered front-to-back.
    ///
    /// A window's top edge is clipped wherever a window in front of it covers it, so the
    /// sheep never walks along a hidden edge. Segments shorter than `minLength`, or with too
    /// little headroom below the top of their screen (`headroom`), are discarded.
    public static func windowTops(
        frontToBack windows: [Rect],
        screens: [Rect],
        headroom: Double,
        minLength: Double = 24
    ) -> [Platform] {
        var result: [Platform] = []
        for (index, window) in windows.enumerated() {
            let y = window.maxY
            var segments = [(window.minX, window.maxX)]
            for front in windows[..<index] where front.minY < y && front.maxY >= y {
                segments = segments.flatMap { subtract(front.minX, front.maxX, from: $0) }
            }
            for (minX, maxX) in segments where maxX - minX >= minLength {
                let midX = (minX + maxX) / 2
                guard let screen = screens.first(where: { midX >= $0.minX && midX <= $0.maxX }),
                      y > screen.minY + 1, y + headroom <= screen.maxY else { continue }
                result.append(Platform(y: y, minX: max(minX, screen.minX), maxX: min(maxX, screen.maxX)))
            }
        }
        return result
    }

    private static func subtract(_ a: Double, _ b: Double, from seg: (Double, Double)) -> [(Double, Double)] {
        let (lo, hi) = seg
        if b <= lo || a >= hi { return [seg] }
        var out: [(Double, Double)] = []
        if a > lo { out.append((lo, a)) }
        if b < hi { out.append((b, hi)) }
        return out
    }
}
