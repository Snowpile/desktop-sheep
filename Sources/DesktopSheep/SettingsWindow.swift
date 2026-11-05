import AppKit
import SheepCore

/// A small settings window built in code (no nib/storyboard, since Xcode isn't required).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private var window: NSWindow?

    private let countLabel = NSTextField(labelWithString: "")
    private let countStepper = NSStepper()
    private let entryPopup = NSPopUpButton()
    private let windowsCheck = NSButton(checkboxWithTitle: "Walk on top of windows", target: nil, action: nil)
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

        for style in EntryStyle.allCases { entryPopup.addItem(withTitle: style.title) }
        entryPopup.target = self
        entryPopup.action = #selector(entryChanged)

        windowsCheck.target = self
        windowsCheck.action = #selector(windowsChanged)

        speedSlider.minValue = PetSettings.speedRange.lowerBound
        speedSlider.maxValue = PetSettings.speedRange.upperBound
        speedSlider.target = self
        speedSlider.action = #selector(speedChanged)
        speedSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let behaviorStack = NSStackView()
        behaviorStack.orientation = .vertical
        behaviorStack.alignment = .leading
        behaviorStack.spacing = 4
        for behavior in PetSettings.toggleableBehaviors {
            let check = NSButton(checkboxWithTitle: Self.title(for: behavior), target: self, action: #selector(behaviorChanged(_:)))
            check.identifier = NSUserInterfaceItemIdentifier(behavior.rawValue)
            behaviorChecks[behavior] = check
            behaviorStack.addArrangedSubview(check)
        }

        let grid = NSGridView(views: [
            [label("Number of pets:"), row(countStepper, countLabel)],
            [label("Entry style:"), entryPopup],
            [label("Windows:"), windowsCheck],
            [label("Speed:"), row(speedSlider, speedLabel)],
            [label("Behaviors:"), behaviorStack],
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.row(at: 4).yPlacement = .top
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
        case .eat: return "Eat grass"
        case .bleat: return "Bleat"
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
        countStepper.integerValue = s.petCount
        countLabel.stringValue = "\(s.petCount)"
        entryPopup.selectItem(at: EntryStyle.allCases.firstIndex(of: s.entryStyle) ?? 0)
        windowsCheck.state = s.walkOnWindows ? .on : .off
        speedSlider.doubleValue = s.speed
        speedLabel.stringValue = String(format: "%.2g×", s.speed)
        for (behavior, check) in behaviorChecks { check.state = s.isEnabled(behavior) ? .on : .off }
    }

    @objc private func countChanged() { store.update { $0.petCount = countStepper.integerValue } }
    @objc private func entryChanged() {
        let i = entryPopup.indexOfSelectedItem
        guard EntryStyle.allCases.indices.contains(i) else { return }
        store.update { $0.entryStyle = EntryStyle.allCases[i] }
    }
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
