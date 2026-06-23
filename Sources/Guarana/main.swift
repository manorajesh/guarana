import AppKit
import Dispatch

private final class CaffeinateController {
    private var process: Process?
    private var activeSince: Date?
    private let caffeinatePath = "/usr/bin/caffeinate"

    var keepDisplayOn = true

    var isRunning: Bool {
        process?.isRunning == true
    }

    var activeDuration: TimeInterval? {
        guard isRunning, let activeSince else { return nil }
        return Date().timeIntervalSince(activeSince)
    }

    var onStateChange: (() -> Void)?

    func start() {
        start(activeSinceOverride: nil)
    }

    func setKeepDisplayOn(_ value: Bool) {
        guard keepDisplayOn != value else { return }

        keepDisplayOn = value
        guard isRunning else {
            onStateChange?()
            return
        }

        let previousActiveSince = activeSince
        stop(notify: false)
        start(activeSinceOverride: previousActiveSince)
    }

    private func start(activeSinceOverride: Date?) {
        guard !isRunning else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: caffeinatePath)
        task.arguments = caffeinateArguments()
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { [weak self, weak task] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.process === task {
                    self.process = nil
                    self.activeSince = nil
                    self.onStateChange?()
                }
            }
        }

        do {
            try task.run()
            process = task
            activeSince = activeSinceOverride ?? Date()
            onStateChange?()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not start caffeinate"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func stop() {
        stop(notify: true)
    }

    private func stop(notify: Bool) {
        guard let task = process else { return }
        process = nil
        activeSince = nil
        task.terminationHandler = nil
        if task.isRunning {
            task.terminate()
            task.waitUntilExit()
        }
        if notify {
            onStateChange?()
        }
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    private func caffeinateArguments() -> [String] {
        var arguments: [String] = []

        if keepDisplayOn {
            arguments.append("-d")
        }

        arguments.append(contentsOf: [
            "-w",
            String(ProcessInfo.processInfo.processIdentifier)
        ])

        return arguments
    }
}

private final class GuaranaIcon {
    static func image(filled: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let outer = NSColor(calibratedWhite: 0.0, alpha: 1.0)
        let ring = NSColor.clear
        let seed = NSColor(calibratedWhite: 0.0, alpha: 1.0)
        let backLeaf = NSColor(calibratedWhite: 0.0, alpha: filled ? 0.68 : 0.62)
        let frontLeaf = NSColor(calibratedWhite: 0.0, alpha: filled ? 0.34 : 0.34)

        drawLeaves(backLeaf: backLeaf, frontLeaf: frontLeaf, filled: filled)
        drawFruit(outer: outer, ring: ring, seed: seed, filled: filled)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawLeaves(backLeaf: NSColor, frontLeaf: NSColor, filled: Bool) {
        let baseLeaf = NSBezierPath()
        baseLeaf.move(to: NSPoint(x: 6.0, y: 13.6))
        baseLeaf.curve(
            to: NSPoint(x: 9.4, y: 21.0),
            controlPoint1: NSPoint(x: 5.6, y: 16.6),
            controlPoint2: NSPoint(x: 6.7, y: 20.8)
        )
        baseLeaf.curve(
            to: NSPoint(x: 13.2, y: 17.1),
            controlPoint1: NSPoint(x: 12.0, y: 21.2),
            controlPoint2: NSPoint(x: 13.7, y: 19.5)
        )
        baseLeaf.curve(
            to: NSPoint(x: 6.0, y: 13.6),
            controlPoint1: NSPoint(x: 11.1, y: 15.9),
            controlPoint2: NSPoint(x: 8.7, y: 14.5)
        )

        guard
            let backPath = baseLeaf.copy() as? NSBezierPath,
            let frontPath = baseLeaf.copy() as? NSBezierPath
        else {
            return
        }

        var frontTransform = AffineTransform(translationByX: -9.6, byY: -17.4)
        frontPath.transform(using: frontTransform)
        frontTransform = AffineTransform(rotationByDegrees: -42.0)
        frontPath.transform(using: frontTransform)
        frontTransform = AffineTransform(translationByX: 9.6, byY: 17.4)
        frontPath.transform(using: frontTransform)
        frontTransform = AffineTransform(translationByX: 4.2, byY: -0.2)
        frontPath.transform(using: frontTransform)

        if filled {
            backLeaf.setFill()
            backPath.fill()
            frontLeaf.setFill()
            frontPath.fill()
        } else {
            backPath.lineWidth = 1.25
            frontPath.lineWidth = 1.25
            backPath.lineJoinStyle = .round
            frontPath.lineJoinStyle = .round

            backLeaf.setStroke()
            backPath.stroke()
            frontLeaf.setStroke()
            frontPath.stroke()
        }
    }

    private static func drawFruit(
        outer: NSRect,
        ring: NSRect,
        seed: NSRect,
        colors: (outer: NSColor, ring: NSColor, seed: NSColor),
        filled: Bool
    ) {
        let outerPath = NSBezierPath(ovalIn: outer)
        let ringPath = NSBezierPath(ovalIn: ring)
        let seedPath = NSBezierPath(ovalIn: seed)

        if filled {
            colors.outer.setFill()
            outerPath.fill()

            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.saveGState()
            context.setBlendMode(.clear)
            context.fillEllipse(in: ring)
            context.restoreGState()

            colors.seed.setFill()
            seedPath.fill()
        } else {
            clearEllipse(in: outer)

            outerPath.lineWidth = 1.35
            ringPath.lineWidth = 1.35
            seedPath.lineWidth = 1.35

            colors.outer.setStroke()
            outerPath.stroke()
            colors.ring.setStroke()
            ringPath.stroke()
            colors.seed.setStroke()
            seedPath.stroke()
        }
    }

    private static func clearEllipse(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setBlendMode(.clear)
        context.fillEllipse(in: rect)
        context.restoreGState()
    }

    private static func drawFruit(
        outer: NSColor,
        ring: NSColor,
        seed: NSColor,
        filled: Bool
    ) {
        drawFruit(
            outer: NSRect(x: 3.0, y: 2.2, width: 16.0, height: 16.0),
            ring: NSRect(x: 6.1, y: 5.3, width: 9.8, height: 9.8),
            seed: NSRect(x: 8.6, y: 7.8, width: 4.8, height: 4.8),
            colors: (outer, ring, seed),
            filled: filled
        )
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let keepDisplayOnDefaultsKey = "keepDisplayOn"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let controller = CaffeinateController()
    private var signalSources: [DispatchSourceSignal] = []
    private var uptimeTimer: Timer?

    override init() {
        UserDefaults.standard.register(defaults: [Self.keepDisplayOnDefaultsKey: true])
        super.init()
        controller.keepDisplayOn = UserDefaults.standard.bool(forKey: Self.keepDisplayOnDefaultsKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        controller.onStateChange = { [weak self] in
            self?.refreshStatusItem()
            self?.updateUptimeTimer()
        }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        installSignalHandlers()
        refreshStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        uptimeTimer?.invalidate()
        controller.stop()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            controller.toggle()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            controller.toggle()
        }
    }

    private func refreshStatusItem() {
        let running = controller.isRunning
        statusItem.button?.image = GuaranaIcon.image(filled: running)
        if running, let duration = controller.activeDuration {
            let mode = controller.keepDisplayOn ? "display wake" : "idle wake"
            statusItem.button?.toolTip = "Guarana \(mode) is on for \(Self.formatDuration(duration))"
        } else {
            statusItem.button?.toolTip = "Guarana is off"
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggleTitle = controller.isRunning ? "Turn Off" : "Turn On"

        if controller.isRunning, let duration = controller.activeDuration {
            let uptimeItem = NSMenuItem(title: "Active: \(Self.formatDuration(duration))", action: nil, keyEquivalent: "")
            uptimeItem.isEnabled = false
            menu.addItem(uptimeItem)
            menu.addItem(.separator())
        }

        let keepDisplayOnItem = NSMenuItem(
            title: "Keep Display On",
            action: #selector(toggleKeepDisplayOnFromMenu(_:)),
            keyEquivalent: ""
        )
        keepDisplayOnItem.target = self
        keepDisplayOnItem.state = controller.keepDisplayOn ? .on : .off
        menu.addItem(keepDisplayOnItem)
        menu.addItem(.separator())

        menu.addItem(
            withTitle: toggleTitle,
            action: #selector(toggleFromMenu(_:)),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit",
            action: #selector(quitFromMenu(_:)),
            keyEquivalent: "q"
        ).target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleFromMenu(_ sender: NSMenuItem) {
        controller.toggle()
    }

    @objc private func toggleKeepDisplayOnFromMenu(_ sender: NSMenuItem) {
        let newValue = !controller.keepDisplayOn
        UserDefaults.standard.set(newValue, forKey: Self.keepDisplayOnDefaultsKey)
        controller.setKeepDisplayOn(newValue)
    }

    @objc private func quitFromMenu(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func updateUptimeTimer() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil

        guard controller.isRunning else { return }

        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatusItem()
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

    private func installSignalHandlers() {
        for signalNumber in [SIGINT, SIGTERM, SIGHUP] {
            signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                self?.controller.stop()
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
