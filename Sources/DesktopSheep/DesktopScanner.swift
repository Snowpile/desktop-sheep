import AppKit
import SheepCore

/// Reads the displays and the on-screen windows into a SheepCore `World`.
///
/// Window bounds, layer and owner come from `CGWindowListCopyWindowInfo`, which macOS
/// provides without Screen Recording permission (only window titles need it), so no
/// permission prompt is triggered.
@MainActor
enum DesktopScanner {
    static func world(headroom: Double, includeWindows: Bool) -> World {
        let screens = NSScreen.screens.map { s -> Rect in
            let f = s.visibleFrame
            return Rect(x: f.minX, y: f.minY, width: f.width, height: f.height)
        }
        guard includeWindows else { return World(screens: screens) }
        let frames = windowFrames()
        return World(
            screens: screens,
            windowTops: World.windowTops(frontToBack: frames, screens: screens, headroom: headroom),
            windows: frames
        )
    }

    /// Frames of normal app windows, front to back, in AppKit global coordinates.
    static func windowFrames() -> [Rect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]],
              let primary = NSScreen.screens.first else { return [] }
        let primaryHeight = primary.frame.maxY
        let ownPID = ProcessInfo.processInfo.processIdentifier

        return list.compactMap { info -> Rect? in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? Int32) != ownPID,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let cg = CGRect(dictionaryRepresentation: dict),
                  cg.width >= 80, cg.height >= 40 else { return nil }
            // CoreGraphics measures from the top of the primary display, AppKit from the bottom.
            return Rect(x: cg.minX, y: primaryHeight - cg.maxY, width: cg.width, height: cg.height)
        }
    }
}
