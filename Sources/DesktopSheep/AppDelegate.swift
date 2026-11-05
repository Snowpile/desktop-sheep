import AppKit
import QuartzCore
import SheepCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = SettingsStore()
    private lazy var settingsWindow = SettingsWindowController(store: store)
    private var flock: [PetController] = []
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var lastScan = 0.0
    private var world = World(screens: [])
    private var rng = SystemRandomNumberGenerator()
    private var removeItem: NSMenuItem?
    private var addItem: NSMenuItem?
    private var walkOnWindowsItem: NSMenuItem?
    private var animalItems: [NSMenuItem] = []
    private var currentAnimalChoice: AnimalChoice?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let count = Self.countArgument() {
            store.persists = false
            store.update { $0.petCount = count }
        }
        setUpMenu()
        rescan()
        syncFlock()
        currentAnimalChoice = store.settings.animal
        store.observe { [weak self] _ in self?.settingsChanged() }

        let timer = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    /// `--count N` on the command line sets the number of pets; nothing is saved in that session.
    private static func countArgument() -> Int? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--count"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    // MARK: Menu

    private func setUpMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Sprites.shared.menuBarIcon()
        item.button?.toolTip = "Desktop Sheep"

        let menu = NSMenu()
        menu.delegate = self
        addItem = add(menu, "Add Pet", #selector(addPetAction), "n")
        removeItem = add(menu, "Remove Pet", #selector(removePetAction), "d")
        let animalMenu = NSMenu()
        for (i, choice) in AnimalChoice.all.enumerated() {
            let item = animalMenu.addItem(withTitle: choice.title, action: #selector(chooseAnimal(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            animalItems.append(item)
        }
        menu.addItem(withTitle: "Animal (All Pets)", action: nil, keyEquivalent: "").submenu = animalMenu
        menu.addItem(.separator())
        walkOnWindowsItem = add(menu, "Walk on Windows", #selector(toggleWalkOnWindows), "")
        add(menu, "Settings…", #selector(showSettings), ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Desktop Sheep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        removeItem?.isEnabled = !flock.isEmpty
        addItem?.isEnabled = flock.count < PetSettings.maxPets
        walkOnWindowsItem?.state = store.settings.walkOnWindows ? .on : .off
        for item in animalItems { item.state = AnimalChoice.all[item.tag] == store.settings.animal ? .on : .off }
    }

    @objc private func addPetAction() { store.update { $0.petCount += 1 } }
    @objc private func removePetAction() { store.update { $0.petCount -= 1 } }
    @objc private func toggleWalkOnWindows() { store.update { $0.walkOnWindows.toggle() } }
    @objc private func showSettings() { settingsWindow.show() }
    @objc private func chooseAnimal(_ sender: NSMenuItem) { store.update { $0.animal = AnimalChoice.all[sender.tag] } }

    // MARK: Flock

    private func settingsChanged() {
        rescan()
        syncFlock()
        // Choosing an animal for all pets converts the existing ones too.
        if store.settings.animal != currentAnimalChoice {
            currentAnimalChoice = store.settings.animal
            for controller in flock {
                controller.sheep.animal = store.settings.animal.pick(using: &rng)
                controller.render()
            }
        }
        var config = PetConfig()
        store.settings.apply(to: &config)
        for controller in flock { controller.sheep.apply(config) }
    }

    /// Adds or removes pets to match the configured count.
    private func syncFlock() {
        guard !world.screens.isEmpty else { return }
        while flock.count > store.settings.petCount { flock.removeLast().close() }
        while flock.count < store.settings.petCount {
            var config = PetConfig()
            store.settings.apply(to: &config)
            let animal = store.settings.animal.pick(using: &rng)
            flock.append(PetController(sheep: Pet.spawn(in: world, rng: &rng, animal: animal, config: config)))
        }
    }

    // MARK: Loop

    @objc private func screensChanged() { rescan() }

    private func rescan() {
        world = DesktopScanner.world(
            headroom: Double(Sprites.shared.size.height),
            includeWindows: store.settings.walkOnWindows
        )
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
