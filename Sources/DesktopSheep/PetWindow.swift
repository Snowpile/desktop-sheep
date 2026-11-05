import AppKit
import QuartzCore
import SheepCore

/// One sheep: its simulation state plus a tiny transparent always-on-top window.
@MainActor
final class PetController {
    var sheep: Pet
    let window: NSPanel
    private let view: PetView
    private var dragOffset = CGPoint.zero
    private var lastDragTime: TimeInterval = 0

    init(sheep: Pet) {
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

        view = PetView(frame: CGRect(origin: .zero, size: size))
        window.contentView = view
        view.controller = self
        render()
        window.orderFrontRegardless()
    }

    var pose: Pose { sheep.pose }

    func render() {
        let size = Sprites.shared.size
        let origin = sheep.spriteOrigin(width: size.width, height: size.height)
        window.setFrameOrigin(CGPoint(x: origin.x.rounded(), y: origin.y.rounded()))
        // Napping on the menu bar needs to be above it.
        let level: NSWindow.Level = sheep.behavior == .menuNap ? .statusBar : .floating
        if window.level != level { window.level = level }
        updatePeekMask(originX: origin.x.rounded(), width: size.width, height: size.height)
        view.layer?.contents = Sprites.shared.image(for: pose, animal: sheep.animal, facing: sheep.facing)
    }

    /// While peeking, hides the part of the pet that is "behind" the window edge.
    private func updatePeekMask(originX: Double, width: Double, height: Double) {
        guard let edge = sheep.peekEdge else {
            if view.layer?.mask != nil { view.layer?.mask = nil }
            return
        }
        let mask = view.layer?.mask ?? CALayer()
        mask.backgroundColor = NSColor.black.cgColor
        let cut = min(max(edge - originX, 0), width)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.frame = sheep.peekHidesRight ? CGRect(x: 0, y: 0, width: cut, height: height)
                                          : CGRect(x: cut, y: 0, width: width - cut, height: height)
        CATransaction.commit()
        if view.layer?.mask == nil { view.layer?.mask = mask }
    }

    /// Lets clicks fall through to whatever is behind, except on the sheep itself.
    func updateClickThrough(mouse: CGPoint) {
        guard sheep.behavior != .dragged else {
            window.ignoresMouseEvents = false
            return
        }
        let local = CGPoint(x: mouse.x - window.frame.minX, y: mouse.y - window.frame.minY)
        let inside = local.x >= 0 && local.y >= 0 && local.x < window.frame.width && local.y < window.frame.height
        let hidden = sheep.peekEdge.map { edge in sheep.peekHidesRight ? mouse.x > edge : mouse.x < edge } ?? false
        let hit = inside && !hidden && Sprites.shared.isOpaque(pose: pose, animal: sheep.animal, facing: sheep.facing, at: local)
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

    /// Right-click a pet to turn it into another animal.
    func rightMouseDown(_ event: NSEvent, in view: NSView) {
        let menu = NSMenu()
        let header = menu.addItem(withTitle: "This pet is a…", action: nil, keyEquivalent: "")
        header.isEnabled = false
        for animal in Animal.allCases {
            let item = menu.addItem(withTitle: animal.title, action: #selector(PetMenuTarget.choose(_:)), keyEquivalent: "")
            item.representedObject = animal.rawValue
            item.target = menuTarget
            item.state = animal == sheep.animal ? .on : .off
        }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    private lazy var menuTarget = PetMenuTarget { [weak self] animal in
        self?.sheep.animal = animal
        self?.render()
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

final class PetView: NSView {
    weak var controller: PetController?

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
    override func rightMouseDown(with event: NSEvent) {
        MainActor.assumeIsolated { controller?.rightMouseDown(event, in: self) }
    }
}

/// Receives the per-pet animal menu choice.
@MainActor
final class PetMenuTarget: NSObject {
    private let onChoose: (Animal) -> Void

    init(onChoose: @escaping (Animal) -> Void) { self.onChoose = onChoose }

    @objc func choose(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let animal = Animal(rawValue: raw) else { return }
        onChoose(animal)
    }
}
