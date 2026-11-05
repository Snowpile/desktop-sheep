import AppKit
import QuartzCore
import SheepCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var flock: [SheepController] = []
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var lastScan = 0.0
    private var world = World(screens: [])
    private var rng = SystemRandomNumberGenerator()
    private var removeItem: NSMenuItem?
    private var walkOnWindowsItem: NSMenuItem?

    private static let maxSheep = 20
    private static let walkOnWindowsKey = "walkOnWindows"
    private var walkOnWindows: Bool {
        get { UserDefaults.standard.object(forKey: Self.walkOnWindowsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.walkOnWindowsKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMenu()
        rescan()
        let count = Self.initialCount()
        for _ in 0..<count { addSheep() }

        let timer = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    /// `--count N` on the command line starts with N sheep.
    private static func initialCount() -> Int {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--count"), i + 1 < args.count, let n = Int(args[i + 1]) {
            return min(max(n, 1), maxSheep)
        }
        return 1
    }

    // MARK: Menu

    private func setUpMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Sprites.shared.menuBarIcon()
        item.button?.toolTip = "Desktop Sheep"

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Add Sheep", action: #selector(addSheepAction), keyEquivalent: "n").target = self
        let remove = menu.addItem(withTitle: "Remove Sheep", action: #selector(removeSheepAction), keyEquivalent: "d")
        remove.target = self
        removeItem = remove
        menu.addItem(.separator())
        let walk = menu.addItem(withTitle: "Walk on Windows", action: #selector(toggleWalkOnWindows), keyEquivalent: "")
        walk.target = self
        walkOnWindowsItem = walk
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Desktop Sheep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        removeItem?.isEnabled = !flock.isEmpty
        walkOnWindowsItem?.state = walkOnWindows ? .on : .off
    }

    @objc private func addSheepAction() { addSheep() }

    @objc private func removeSheepAction() {
        guard let last = flock.popLast() else { return }
        last.close()
    }

    @objc private func toggleWalkOnWindows() {
        walkOnWindows.toggle()
        rescan()
    }

    private func addSheep() {
        guard flock.count < Self.maxSheep, !world.screens.isEmpty else { return }
        flock.append(SheepController(sheep: Sheep.spawn(in: world, rng: &rng)))
    }

    // MARK: Loop

    @objc private func screensChanged() { rescan() }

    private func rescan() {
        world = DesktopScanner.world(headroom: Double(Sprites.shared.size.height), includeWindows: walkOnWindows)
        lastScan = CACurrentMediaTime()
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.1)
        lastTick = now
        if now - lastScan > 0.4 { rescan() }

        let mouse = NSEvent.mouseLocation
        for controller in flock {
            controller.sheep.step(dt: dt, world: world, rng: &rng)
            controller.render()
            controller.updateClickThrough(mouse: mouse)
        }
    }
}
