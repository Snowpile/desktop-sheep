import AppKit
import QuartzCore
import SheepCore

/// One sheep: its simulation state plus a tiny transparent always-on-top window.
@MainActor
final class SheepController {
    var sheep: Sheep
    let window: NSPanel
    private let view: SheepView
    private var dragOffset = CGPoint.zero
    private var lastDragTime: TimeInterval = 0

    init(sheep: Sheep) {
        self.sheep = sheep
        let size = Sprites.shared.size
        window = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.isMovable = false

        view = SheepView(frame: CGRect(origin: .zero, size: size))
        window.contentView = view
        view.controller = self
        render()
        window.orderFrontRegardless()
    }

    var pose: Pose { SheepArt.pose(for: sheep.behavior, time: sheep.animationTime) }

    func render() {
        let size = Sprites.shared.size
        window.setFrameOrigin(CGPoint(x: (sheep.x - size.width / 2).rounded(), y: sheep.y.rounded()))
        view.layer?.contents = Sprites.shared.image(for: pose, facing: sheep.facing)
    }

    /// Lets clicks fall through to whatever is behind, except on the sheep itself.
    func updateClickThrough(mouse: CGPoint) {
        guard sheep.behavior != .dragged else {
            window.ignoresMouseEvents = false
            return
        }
        let local = CGPoint(x: mouse.x - window.frame.minX, y: mouse.y - window.frame.minY)
        let inside = local.x >= 0 && local.y >= 0 && local.x < window.frame.width && local.y < window.frame.height
        let hit = inside && Sprites.shared.isOpaque(pose: pose, facing: sheep.facing, at: local)
        if window.ignoresMouseEvents == hit { window.ignoresMouseEvents = !hit }
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }

    // MARK: Dragging

    func mouseDown(_ event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        dragOffset = CGPoint(x: sheep.x - mouse.x, y: sheep.y - mouse.y)
        lastDragTime = event.timestamp
        sheep.beginDrag()
        render()
    }

    func mouseDragged(_ event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let dt = max(event.timestamp - lastDragTime, 1.0 / 240)
        lastDragTime = event.timestamp
        sheep.drag(toX: mouse.x + dragOffset.x, y: mouse.y + dragOffset.y, dt: dt)
        render()
    }

    func mouseUp(_ event: NSEvent) {
        // Holding still before letting go drops the sheep instead of throwing it.
        if event.timestamp - lastDragTime > 0.08 {
            sheep.vx = 0
            sheep.vy = 0
        }
        sheep.endDrag()
    }
}

final class SheepView: NSView {
    weak var controller: SheepController?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layer?.contentsGravity = .resize
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { MainActor.assumeIsolated { controller?.mouseDown(event) } }
    override func mouseDragged(with event: NSEvent) { MainActor.assumeIsolated { controller?.mouseDragged(event) } }
    override func mouseUp(with event: NSEvent) { MainActor.assumeIsolated { controller?.mouseUp(event) } }
}
