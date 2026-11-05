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
    private var loginItem: NSMenuItem?
    private var animalItems: [NSMenuItem] = []
    private var entryItems: [NSMenuItem] = []
    private var finaleItem: NSMenuItem?
    private var bringBackItem: NSMenuItem?
    /// How many pets there were before the last finale, so they can be brought back.
    private var petsBeforeFinale = 0
    private let sounds = SoundPlayer()
    private var lastBehaviors: [UInt64: Behavior] = [:]
    private var soundsItem: NSMenuItem?
    private var treats: [Treat] = []
    private var treatWindows: [Int: TreatWindow] = [:]
    private var nextTreatID = 1
    private var lastMouse = CGPoint.zero
    private var mouseMonitors: [Any] = []
    /// Times (CACurrentMediaTime) when a new pet will show up after one walked off.
    private var pendingArrivals: [Double] = []
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

        // Option-click anywhere drops a treat. Global mouse monitors need no special permission.
        let onClick: (NSEvent) -> Void = { [weak self] event in
            guard event.modifierFlags.contains(.option) else { return }
            MainActor.assumeIsolated { self?.dropTreat(at: NSEvent.mouseLocation) }
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: onClick) { mouseMonitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { event in onClick(event); return event }) {
            mouseMonitors.append(m)
        }

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
        let bringBack = add(menu, "Bring Back Pets", #selector(bringBackPets), "")
        bringBack.isHidden = true
        bringBackItem = bringBack
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
        let entryMenu = NSMenu()
        for (i, style) in EntryStyle.allCases.enumerated() {
            let item = entryMenu.addItem(withTitle: style.title, action: #selector(chooseEntry(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            entryItems.append(item)
        }
        menu.addItem(withTitle: "New Pets Arrive By", action: nil, keyEquivalent: "").submenu = entryMenu
        let finaleMenu = NSMenu()
        for (i, style) in FinaleStyle.allCases.enumerated() {
            let item = finaleMenu.addItem(withTitle: style.title + "…", action: #selector(startFinale(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
        }
        finaleItem = menu.addItem(withTitle: "Grand Finale", action: nil, keyEquivalent: "")
        finaleItem?.submenu = finaleMenu
        menu.addItem(.separator())
        walkOnWindowsItem = add(menu, "Walk on Windows", #selector(toggleWalkOnWindows), "")
        add(menu, "Drop a Treat (or ⌥-click anywhere)", #selector(dropTreatAction), "t")
        add(menu, "Settings…", #selector(showSettings), ",")
        soundsItem = add(menu, "Sounds", #selector(toggleSounds), "")
        loginItem = add(menu, "Launch at Login", #selector(toggleLaunchAtLogin), "")
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
        finaleItem?.isEnabled = flock.contains { $0.sheep.behavior != .countdown && $0.sheep.behavior != .finale }
        bringBackItem?.isHidden = !(flock.isEmpty && petsBeforeFinale > 0)
        bringBackItem?.title = petsBeforeFinale == 1 ? "Bring Back a Pet" : "Bring Back \(petsBeforeFinale) Pets"
        for item in finaleItem?.submenu?.items ?? [] {
            item.state = FinaleStyle.allCases[item.tag] == store.settings.finaleStyle ? .on : .off
        }
        addItem?.isEnabled = flock.count < PetSettings.maxPets
        walkOnWindowsItem?.state = store.settings.walkOnWindows ? .on : .off
        soundsItem?.state = store.settings.sounds ? .on : .off
        loginItem?.isEnabled = LaunchAtLogin.isAvailable
        loginItem?.state = LaunchAtLogin.isEnabled ? .on : (LaunchAtLogin.needsApproval ? .mixed : .off)
        loginItem?.toolTip = LaunchAtLogin.isAvailable ? nil : "Available when running Desktop Sheep.app"
        for item in entryItems { item.state = EntryStyle.allCases[item.tag] == store.settings.entryStyle ? .on : .off }
        for item in animalItems { item.state = AnimalChoice.all[item.tag] == store.settings.animal ? .on : .off }
    }

    @objc private func addPetAction() { store.update { $0.petCount += 1 } }
    @objc private func removePetAction() { store.update { $0.petCount -= 1 } }
    @objc private func toggleWalkOnWindows() { store.update { $0.walkOnWindows.toggle() } }
    @objc private func showSettings() { settingsWindow.show() }
    @objc private func toggleLaunchAtLogin() { LaunchAtLogin.toggle() }
    @objc private func toggleSounds() { store.update { $0.sounds.toggle() } }

    /// Sounds for what pets just started doing.
    private func playSounds(for pets: [Pet], now: Double) {
        defer { lastBehaviors = Dictionary(uniqueKeysWithValues: pets.map { ($0.id, $0.behavior) }) }
        guard store.settings.sounds else { return }
        for pet in pets where lastBehaviors[pet.id] != pet.behavior && lastBehaviors[pet.id] != nil {
            switch pet.behavior {
            case .call: sounds.play(.call(for: pet.animal), now: now)
            case .impact, .tumble: sounds.play(.thud, now: now)
            case .startled: sounds.play(.pop, now: now)
            case .finale: sounds.play(.finale(pet.finaleStyle), now: now)
            default: break
            }
        }
    }
    @objc private func startFinale(_ sender: NSMenuItem) {
        let style = FinaleStyle.allCases[sender.tag]
        store.update { $0.finaleStyle = style }
        let count = flock.count
        guard count > 0 else { return }
        let alert = NSAlert()
        alert.messageText = "Grand finale?"
        alert.informativeText = (count == 1 ? "Your pet will " : "All \(count) pets will ") + style.phrase
            + " after a short countdown. You can bring them back afterwards."
        alert.addButton(withTitle: "Do It")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        petsBeforeFinale = count
        for controller in flock { controller.sheep.beginFinale(style: style) }
    }

    @objc private func dropTreatAction() {
        // Over a random pet, or the middle of the main screen.
        if let pet = flock.randomElement()?.sheep {
            dropTreat(at: CGPoint(x: pet.x + Double.random(in: -150...150, using: &rng), y: pet.y + 200))
        } else if let s = world.screens.first {
            dropTreat(at: CGPoint(x: s.minX + s.width / 2, y: s.maxY - 100))
        }
    }

    private func dropTreat(at point: CGPoint) {
        guard treats.count < 10 else { return }
        let treat = Treat(id: nextTreatID, x: point.x, y: point.y)
        nextTreatID += 1
        treats.append(treat)
        let window = TreatWindow(id: treat.id)
        window.move(to: treat)
        treatWindows[treat.id] = window
    }

    @objc private func bringBackPets() {
        let count = petsBeforeFinale
        petsBeforeFinale = 0
        store.update { $0.petCount = count }
    }

    @objc private func chooseEntry(_ sender: NSMenuItem) { store.update { $0.entryStyle = EntryStyle.allCases[sender.tag] } }
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
            flock.append(PetController(sheep: Pet.spawn(in: world, rng: &rng, animal: animal, entry: store.settings.entryStyle, config: config)))
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
        if let due = pendingArrivals.firstIndex(where: { $0 <= now }) {
            pendingArrivals.remove(at: due)
            if store.settings.walkOffScreen && flock.count < PetSettings.maxPets { store.update { $0.petCount += 1 } }
        }

        let mouse = NSEvent.mouseLocation
        var pets = flock.map(\.sheep)
        for i in pets.indices {
            pets[i].step(dt: dt, world: Social.world(world, for: i, in: pets), rng: &rng)
        }
        Social.interact(&pets, dt: dt, rng: &rng)
        let speed = hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) / max(dt, 1.0 / 120)
        lastMouse = mouse
        Cursor.react(&pets, cursor: CursorInput(x: mouse.x, y: mouse.y, speed: speed), dt: dt, rng: &rng)
        Cursor.step(&treats, pets: &pets, world: world, dt: dt, rng: &rng)
        playSounds(for: pets, now: now)
        for (id, window) in treatWindows {
            if let treat = treats.first(where: { $0.id == id }) { window.move(to: treat) } else {
                window.close()
                treatWindows[id] = nil
            }
        }
        for (controller, pet) in zip(flock, pets) {
            controller.sheep = pet
            controller.render()
            controller.updateClickThrough(mouse: mouse)
        }
        // Pets that finished their finale or walked off-screen leave for good.
        if flock.contains(where: { $0.sheep.isGone }) {
            for controller in flock where controller.sheep.isGone {
                controller.close()
                if controller.sheep.exit == .walkedOff && store.settings.newPetAfterWalkOff
                    && Double.random(in: 0..<1, using: &rng) < 0.6 {
                    pendingArrivals.append(now + Double.random(in: 15...60, using: &rng))
                }
            }
            flock.removeAll { $0.sheep.isGone }
            store.update { $0.petCount = flock.count }
        }
    }
}
