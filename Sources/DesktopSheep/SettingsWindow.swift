import AppKit
import SheepCore

/// A small settings window built in code (no nib/storyboard, since Xcode isn't required).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private var window: NSWindow?

    private let animalPopup = NSPopUpButton()
    private let countLabel = NSTextField(labelWithString: "")
    private let countStepper = NSStepper()
    private let entryPopup = NSPopUpButton()
    private let finalePopup = NSPopUpButton()
    private let windowsCheck = NSButton(checkboxWithTitle: "Walk on top of windows", target: nil, action: nil)
    private let walkOffCheck = NSButton(checkboxWithTitle: "Walk off the screen edge and leave", target: nil, action: nil)
    private let newPetCheck = NSButton(checkboxWithTitle: "…and sometimes a new pet shows up later", target: nil, action: nil)
    private let speedSlider = NSSlider()
    private let speedLabel = NSTextField(labelWithString: "")
    private var behaviorChecks: [Behavior: NSButton] = [:]

    init(store: SettingsStore) {
        self.store = store
        super.init()
        store.observe { [weak self] _ in self?.refresh() }
    }

    func show() {
        if window == nil { window = makeWindow() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Desktop Sheep Settings"
        w.isReleasedWhenClosed = false
        w.delegate = self

        countStepper.minValue = 0
        countStepper.maxValue = Double(PetSettings.maxPets)
        countStepper.increment = 1
        countStepper.target = self
        countStepper.action = #selector(countChanged)

        for choice in AnimalChoice.all { animalPopup.addItem(withTitle: choice.title) }
        animalPopup.target = self
        animalPopup.action = #selector(animalChanged)

        for style in EntryStyle.allCases { entryPopup.addItem(withTitle: style.title) }
        entryPopup.target = self
        entryPopup.action = #selector(entryChanged)

        for style in FinaleStyle.allCases { finalePopup.addItem(withTitle: style.title) }
        finalePopup.target = self
        finalePopup.action = #selector(finaleChanged)

        windowsCheck.target = self
        windowsCheck.action = #selector(windowsChanged)
        walkOffCheck.target = self
        walkOffCheck.action = #selector(walkOffChanged)
        newPetCheck.target = self
        newPetCheck.action = #selector(newPetChanged)
        let movement = NSStackView(views: [windowsCheck, walkOffCheck, newPetCheck])
        movement.orientation = .vertical
        movement.alignment = .leading
        movement.spacing = 4

        speedSlider.minValue = PetSettings.speedRange.lowerBound
        speedSlider.maxValue = PetSettings.speedRange.upperBound
        speedSlider.target = self
        speedSlider.action = #selector(speedChanged)
        speedSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        // Two columns of checkboxes.
        let checks = PetSettings.toggleableBehaviors.map { behavior -> NSButton in
            let check = NSButton(checkboxWithTitle: Self.title(for: behavior), target: self, action: #selector(behaviorChanged(_:)))
            check.identifier = NSUserInterfaceItemIdentifier(behavior.rawValue)
            behaviorChecks[behavior] = check
            return check
        }
        let half = (checks.count + 1) / 2
        let columns = [Array(checks[..<half]), Array(checks[half...])].map { column -> NSStackView in
            let stack = NSStackView(views: column)
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 4
            return stack
        }
        let behaviorStack = NSStackView(views: columns)
        behaviorStack.orientation = .horizontal
        behaviorStack.alignment = .top
        behaviorStack.spacing = 16

        let grid = NSGridView(views: [
            [label("Animal:"), animalPopup],
            [label("Number of pets:"), row(countStepper, countLabel)],
            [label("Entry style:"), entryPopup],
            [label("Grand finale:"), finalePopup],
            [label("Wandering:"), movement],
            [label("Speed:"), row(speedSlider, speedLabel)],
            [label("Behaviors:"), behaviorStack],
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.row(at: grid.numberOfRows - 1).yPlacement = .top
        for i in 0..<grid.numberOfRows where grid.cell(atColumnIndex: 1, rowIndex: i).contentView is NSStackView {
            grid.row(at: i).yPlacement = .top
        }
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
        ])
        w.contentView = content
        w.center()
        return w
    }

    static func title(for behavior: Behavior) -> String {
        switch behavior {
        case .walk: return "Walk"
        case .run: return "Run"
        case .sit: return "Sit"
        case .sleep: return "Sleep"
        case .eat: return "Eat (grass, fish, bones…)"
        case .call: return "Call (bleat, meow, bark…)"
        case .climb: return "Climb walls and windows"
        case .hang: return "Hang from window edges"
        case .tumble: return "Trip and tumble"
        case .dig: return "Dig"
        case .butterfly: return "Chase butterflies"
        case .yawn: return "Yawn (contagious)"
        case .nuzzle: return "Nuzzle"
        case .chase: return "Chase and tag"
        case .follow: return "Follow the leader"
        case .playFight: return "Play-fight"
        case .ride: return "Stack up on each other"
        case .chaseCursor: return "Chase the mouse cursor"
        case .startled: return "Startle at fast mouse moves"
        default: return behavior.rawValue.capitalized
        }
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }

    private func row(_ views: NSView...) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.spacing = 6
        return s
    }

    private func refresh() {
        let s = store.settings
        animalPopup.selectItem(at: AnimalChoice.all.firstIndex(of: s.animal) ?? 0)
        countStepper.integerValue = s.petCount
        countLabel.stringValue = "\(s.petCount)"
        entryPopup.selectItem(at: EntryStyle.allCases.firstIndex(of: s.entryStyle) ?? 0)
        finalePopup.selectItem(at: FinaleStyle.allCases.firstIndex(of: s.finaleStyle) ?? 0)
        windowsCheck.state = s.walkOnWindows ? .on : .off
        walkOffCheck.state = s.walkOffScreen ? .on : .off
        newPetCheck.state = s.newPetAfterWalkOff ? .on : .off
        newPetCheck.isEnabled = s.walkOffScreen
        speedSlider.doubleValue = s.speed
        speedLabel.stringValue = String(format: "%.2g×", s.speed)
        for (behavior, check) in behaviorChecks { check.state = s.isEnabled(behavior) ? .on : .off }
    }

    @objc private func animalChanged() {
        let i = animalPopup.indexOfSelectedItem
        guard AnimalChoice.all.indices.contains(i) else { return }
        store.update { $0.animal = AnimalChoice.all[i] }
    }
    @objc private func countChanged() { store.update { $0.petCount = countStepper.integerValue } }
    @objc private func entryChanged() {
        let i = entryPopup.indexOfSelectedItem
        guard EntryStyle.allCases.indices.contains(i) else { return }
        store.update { $0.entryStyle = EntryStyle.allCases[i] }
    }
    @objc private func finaleChanged() {
        let i = finalePopup.indexOfSelectedItem
        guard FinaleStyle.allCases.indices.contains(i) else { return }
        store.update { $0.finaleStyle = FinaleStyle.allCases[i] }
    }
    @objc private func walkOffChanged() { store.update { $0.walkOffScreen = walkOffCheck.state == .on } }
    @objc private func newPetChanged() { store.update { $0.newPetAfterWalkOff = newPetCheck.state == .on } }
    @objc private func windowsChanged() { store.update { $0.walkOnWindows = windowsCheck.state == .on } }
    @objc private func speedChanged() {
        // Snap to quarter steps so the label stays tidy.
        store.update { $0.speed = (speedSlider.doubleValue * 4).rounded() / 4 }
    }
    @objc private func behaviorChanged(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let behavior = Behavior(rawValue: raw) else { return }
        store.update { $0.setEnabled(behavior, sender.state == .on) }
    }
}
