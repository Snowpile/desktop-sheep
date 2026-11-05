import AppKit
import SheepCore

/// A small click-through window showing one treat.
@MainActor
final class TreatWindow {
    let id: Int
    private let window: NSPanel
    private static let image: CGImage? = Sprites.makeImage(PetArt.treatSprite(), mirrored: false)
    private static let size = CGSize(width: 24, height: 16)

    init(id: Int) {
        self.id = id
        window = NSPanel(contentRect: CGRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        let view = NSView(frame: CGRect(origin: .zero, size: Self.size))
        view.wantsLayer = true
        view.layer?.magnificationFilter = .nearest
        view.layer?.contents = Self.image
        window.contentView = view
        window.orderFrontRegardless()
    }

    func move(to treat: Treat) {
        window.setFrameOrigin(CGPoint(x: (treat.x - Self.size.width / 2).rounded(), y: treat.y.rounded()))
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}
