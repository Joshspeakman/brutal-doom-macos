import AppKit
import GameController

final class Launcher: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = CollectionStore(base: (ProcessInfo.processInfo.environment["BRUTAL_DOOM_DATA_DIR"] ?? Bundle.main.object(forInfoDictionaryKey: "BrutalDoomDataDirectory") as? String).map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Games/Brutal Doom"))
    var games: [Game] = []
    var selected = 0
    var game: Game { games[selected] }
    var window: NSWindow!
    var background: Backdrop!
    var main = FlippedView(frame: NSRect(x: 0, y: 0, width: 780, height: 650))
    var overlay: Panel?
    var section: String?
    var process: Process?
    var log: FileHandle?
    /// Quick exit from a controller: View + Menu held 1.5 s ends the running game (GZDoom has no button combos to bind).
    var quitWatch: Timer?, quitSince: Date?, quitRequested = false
    var gameButton: MetalButton!
    var gameVersion: NSTextField!
    var descriptionField: NSTextField!
    var status: NSTextField!
    var play: MetalButton!
    var back: MetalButton!
    var summaries: [NSTextField] = []
    var settingLabels: [NSTextField] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(), item = NSMenuItem()
        menu.addItem(item); item.submenu = NSMenu()
        item.submenu?.addItem(withTitle: "Quit Brutal Doom", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        do {
            games = try JSONDecoder().decode([Game].self, from: Data(contentsOf: store.base.appendingPathComponent("Games.json")))
            guard !games.isEmpty, Set(games.map(\.id)).count == games.count else { throw NSError(domain: "BrutalDoom", code: 2, userInfo: [NSLocalizedDescriptionKey: "The game catalog is empty or contains duplicate entries."]) }
            selected = games.firstIndex { $0.id == UserDefaults.standard.string(forKey: "lastGame") } ?? 0
            buildWindow(); refresh()
            if ProcessInfo.processInfo.environment["BRUTAL_DOOM_QA_PLAY"] != nil {     // development: Play pressed once up
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.startGame(NSButton()) }
            }
            // BRUTAL_DOOM_LAUNCHER_SHOT=<png>: the window drawn to an image instead of shown (screenshots for the README)
            if let shot = ProcessInfo.processInfo.environment["BRUTAL_DOOM_LAUNCHER_SHOT"] {
                NSApp.setActivationPolicy(.accessory)
                let view = window.contentView!; view.layoutSubtreeIfNeeded()
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { NSApp.terminate(nil); return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: shot))
                NSApp.terminate(nil); return
            }
            window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        } catch { showError(error); NSApp.terminate(nil) }
    }
    func button(_ title: String, frame: NSRect, action: Selector, tag: Int = 0, parent: NSView) -> MetalButton {
        let b = MetalButton(frame: frame); b.title = title; b.target = self; b.action = action; b.tag = tag
        b.isBordered = false; b.setAccessibilityLabel(title); parent.addSubview(b); return b
    }
    func buildWindow() {
        window = NSWindow(contentRect: main.bounds, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Brutal Doom Collection"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(white: 0.045, alpha: 1); window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false; window.delegate = self
        let assets = Bundle.main.resourceURL?.appendingPathComponent("LauncherArt") ?? store.base.appendingPathComponent("LauncherArt")
        background = Backdrop(frame: main.bounds, assets: FileManager.default.fileExists(atPath: assets.path) ? assets : store.base.appendingPathComponent("LauncherArt"))
        window.contentView = background; background.addSubview(main)
        let gamePanel = Panel(frame: NSRect(x: 40, y: 263, width: 700, height: 100)); gamePanel.framed = false; main.addSubview(gamePanel)
        gamePanel.addSubview(label("GAME", NSRect(x: 24, y: 22, width: 110, height: 28), size: 21, color: gold, bold: true))
        _ = button("◀", frame: NSRect(x: 144, y: 14, width: 40, height: 40), action: #selector(stepGame), tag: -1, parent: gamePanel)
        gameButton = button("", frame: NSRect(x: 194, y: 14, width: 430, height: 40), action: #selector(gameMenu), parent: gamePanel)
        gameButton.setAccessibilityLabel("Choose game")
        _ = button("▶", frame: NSRect(x: 634, y: 14, width: 40, height: 40), action: #selector(stepGame), tag: 1, parent: gamePanel)
        gameVersion = label("", NSRect(x: 20, y: 66, width: 660, height: 23), size: 12, color: muted, align: .center); gamePanel.addSubview(gameVersion)
        for (i, title) in ["DISPLAY", "GRAPHICS", "CONTROLS", "FILES"].enumerated() {
            _ = button(title, frame: NSRect(x: 40 + i * 180, y: 391, width: 160, height: 52), action: #selector(openSection), tag: i, parent: main)
            let summary = label("", NSRect(x: 35 + i * 180, y: 451, width: 170, height: 34), size: 11, color: muted, align: .center)
            summaries.append(summary); main.addSubview(summary)
        }
        descriptionField = label("", NSRect(x: 62, y: 497, width: 656, height: 44), size: 12, color: parchment, align: .center); main.addSubview(descriptionField)
        status = label("", NSRect(x: 50, y: 544, width: 680, height: 20), size: 11, color: muted, align: .center); background.addSubview(status)
        back = button("QUIT", frame: NSRect(x: 158, y: 582, width: 220, height: 54), action: #selector(backOrQuit), parent: background); back.keyEquivalent = "\u{1b}"
        play = button("PLAY", frame: NSRect(x: 402, y: 582, width: 220, height: 54), action: #selector(startGame), parent: background); play.primary = true; play.keyEquivalent = "\r"
        window.initialFirstResponder = gameButton
    }
    func currentValue(_ setting: Setting, ini: IniFile) -> String {
        ini.value(section: setting.perGame ? game.configSection : "GlobalSettings", key: setting.key) ?? setting.fallback
    }
    func settingText(_ setting: Setting, ini: IniFile) -> String {
        let value = currentValue(setting, ini: ini)
        return setting.values.firstIndex(of: value).map { setting.labels[$0] } ?? "Custom (\(value))"
    }
    func refresh() {
        background.gameID = game.id
        gameButton.title = game.shortTitle; gameButton.setAccessibilityValue(game.title); gameButton.needsDisplay = true
        gameVersion.stringValue = game.version; descriptionField.stringValue = game.description
        do {
            let ini = try store.config(game)
            summaries[0].stringValue = [displaySettings[0], displaySettings[1]].map { settingText($0, ini: ini) }.joined(separator: " · ")
            summaries[1].stringValue = "\(settingText(graphicsSettings[0], ini: ini)) textures · \(currentValue(graphicsSettings[1], ini: ini) == "true" ? "Lights on" : "Lights off")"
            summaries[2].stringValue = "Keys for this game"
            summaries[3].stringValue = "Saves · Guide · Game files"
            status.stringValue = game.id == "hexen" ? "Beta release · Each game keeps its own settings and saves" : "Each game keeps its own settings and saves"
            play.isEnabled = true
        } catch { status.stringValue = "Settings unavailable — open Files to check the installation"; play.isEnabled = false }
    }
    @objc func stepGame(_ sender: NSButton) { selectGame((selected + sender.tag + games.count) % games.count) }
    func selectGame(_ index: Int) { selected = index; UserDefaults.standard.set(game.id, forKey: "lastGame"); refresh() }
    @objc func gameMenu(_ sender: NSButton) {
        let menu = NSMenu()
        for (i, game) in games.enumerated() {
            let item = NSMenuItem(title: game.title, action: #selector(menuGame), keyEquivalent: ""); item.tag = i; item.target = self; item.state = i == selected ? .on : .off; menu.addItem(item)
        }
        menu.popUp(positioning: menu.items[selected], at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    @objc func menuGame(_ sender: NSMenuItem) { selectGame(sender.tag) }
    @objc func openSection(_ sender: NSButton) { showSection(["Display", "Graphics", "Controls", "Files"][sender.tag]) }
    func showSection(_ title: String) {
        overlay?.removeFromSuperview(); section = title; main.isHidden = true
        let p = Panel(frame: NSRect(x: 40, y: 159, width: 700, height: 409)); overlay = p; background.addSubview(p)
        p.addSubview(label(title.uppercased(), NSRect(x: 20, y: 20, width: 660, height: 32), size: 24, color: gold, bold: true, align: .center))
        let rule = NSBox(frame: NSRect(x: 30, y: 64, width: 640, height: 1)); rule.boxType = .separator; p.addSubview(rule)
        back.title = "BACK"; back.setAccessibilityLabel("Back"); back.needsDisplay = true
        status.isHidden = true
        if title == "Display" || title == "Graphics" {
            let settings = title == "Display" ? displaySettings : graphicsSettings
            settingLabels = []
            do {
                let ini = try store.config(game)
                for (i, setting) in settings.enumerated() {
                    let y = 78 + i * 76
                    p.addSubview(label(setting.title, NSRect(x: 30, y: y + 7, width: 285, height: 28), size: 17, color: gold, bold: true))
                    let left = button("◀", frame: NSRect(x: 340, y: y, width: 36, height: 34), action: #selector(changeSetting), tag: i * 2, parent: p); left.setAccessibilityLabel("Previous " + setting.title.lowercased())
                    let value = label(settingText(setting, ini: ini), NSRect(x: 382, y: y + 7, width: 224, height: 25), size: 17, align: .center); settingLabels.append(value); p.addSubview(value)
                    let right = button("▶", frame: NSRect(x: 614, y: y, width: 36, height: 34), action: #selector(changeSetting), tag: i * 2 + 1, parent: p); right.setAccessibilityLabel("Next " + setting.title.lowercased())
                    p.addSubview(label(setting.note, NSRect(x: 30, y: y + 41, width: 620, height: 26), size: 11, color: muted))
                }
            } catch { showError(error) }
        } else if title == "Controls" {
            p.addSubview(label(game.shortTitle, NSRect(x: 30, y: 80, width: 640, height: 26), size: 17, color: gold, bold: true))
            let text = "WASD  Move                  Mouse  Aim\nLeft click  Attack          Right click  Alternate attack\nE  Use / open                 Space  Jump\nControl  Crouch             Mouse wheel  Change weapon\n\n" + game.controls + "\n\nEscape  Menu    F6  Quick save    F9  Quick load\nUse Fn for function keys if your keyboard requires it."
            let field = label(text, NSRect(x: 32, y: 119, width: 636, height: 230), size: 14)
            field.font = .systemFont(ofSize: 14); p.addSubview(field)
            p.addSubview(label("These are the starting bindings. Customize Controls in the game\nshows your current bindings and lets you change them.", NSRect(x: 32, y: 355, width: 636, height: 40), size: 11, color: muted))
        } else {
            p.addSubview(label(game.shortTitle, NSRect(x: 30, y: 83, width: 640, height: 26), size: 17, color: gold, bold: true))
            let actions = [("SAVED GAMES", "Open this game's saves in Finder"), ("GAME FOLDER", "Open the installed collection"), ("READ THE GUIDE", "Game details, controls and author documentation")]
            for (i, row) in actions.enumerated() {
                _ = button(row.0, frame: NSRect(x: 30, y: 127 + i * 82, width: 250, height: 45), action: #selector(openFile), tag: i, parent: p)
                p.addSubview(label(row.1, NSRect(x: 304, y: 138 + i * 82, width: 348, height: 38), size: 12, color: muted))
            }
        }
        window.recalculateKeyViewLoop()
    }
    @objc func changeSetting(_ sender: NSButton) {
        let settings = section == "Display" ? displaySettings : graphicsSettings
        let i = sender.tag / 2, setting = settings[sender.tag / 2], direction = sender.tag % 2 == 0 ? -1 : 1
        do {
            let ini = try store.config(game), value = currentValue(setting, ini: ini)
            let index = setting.values.firstIndex(of: value) ?? (direction == 1 ? -1 : 0)
            let next = (index + direction + setting.values.count) % setting.values.count
            try store.update(setting, value: setting.values[next], game: game)
            settingLabels[i].stringValue = setting.labels[next]; refresh()
        } catch { showError(error) }
    }
    @objc func openFile(_ sender: NSButton) {
        do {
            let target: URL
            switch sender.tag {
            case 0:
                target = try store.path("Profiles/" + game.profile + "/Saves")
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            case 1: target = store.base
            default: target = store.base.appendingPathComponent("START HERE.txt")
            }
            NSWorkspace.shared.open(target)
        } catch { showError(error) }
    }
    @objc func backOrQuit(_ sender: NSButton) {
        if section != nil {
            overlay?.removeFromSuperview(); overlay = nil; section = nil; main.isHidden = false; status.isHidden = false
            back.title = "QUIT"; back.setAccessibilityLabel("Quit"); back.needsDisplay = true
            window.makeFirstResponder(gameButton); refresh()
        } else { NSApp.terminate(nil) }
    }
    @objc func startGame(_ sender: NSButton) {
        if let p = process, p.isRunning { NSRunningApplication(processIdentifier: p.processIdentifier)?.activate(options: []); return }
        let launchedGame = game
        do {
            let fm = FileManager.default, executable = try store.path("Engine/GZDoom.app/Contents/MacOS/gzdoom")
            for required in [executable, try store.path(game.iwad)] + (try game.mods.map { try store.path($0) }) {
                guard fm.fileExists(atPath: required.path) else { throw NSError(domain: "BrutalDoom", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing file: \(required.lastPathComponent). Check the collection's game folder."]) }
            }
            let profile = try store.path("Profiles/" + game.profile)
            for folder in ["Saves", "Screenshots"] { try fm.createDirectory(at: profile.appendingPathComponent(folder), withIntermediateDirectories: true) }
            let config = try store.configURL(game)
            if !fm.fileExists(atPath: config.path) { try fm.copyItem(at: store.path(game.defaults), to: config) }
            let logURL = profile.appendingPathComponent("Last Run.log")
            if !fm.fileExists(atPath: logURL.path) { fm.createFile(atPath: logURL.path, contents: nil) }
            let output = try FileHandle(forWritingTo: logURL); try output.truncate(atOffset: 0); log = output
            let child = Process(); child.executableURL = executable; child.currentDirectoryURL = store.base; child.arguments = try store.arguments(game)
            child.standardOutput = output; child.standardError = output
            child.terminationHandler = { p in DispatchQueue.main.async {
                try? output.close(); self.log = nil; self.process = nil
                NSApp.unhide(nil); self.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); self.refresh()
                self.quitWatch?.invalidate()
                if p.terminationStatus != 0 && !self.quitRequested {
                    let alert = NSAlert(); alert.messageText = "\(launchedGame.title) stopped unexpectedly"
                    alert.informativeText = "Its Last Run.log is in the game's profile folder."
                    alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Show Log")
                    if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.activateFileViewerSelecting([logURL]) }
                }
            }}
            process = child
            do { try child.run() } catch { process = nil; try? output.close(); log = nil; throw error }
            if #available(macOS 11.3, *) { GCController.shouldMonitorBackgroundEvents = true }   // the game is frontmost; the launcher still sees the pad
            quitRequested = false; quitSince = nil; quitWatch?.invalidate()
            let started = Date(), qa = ProcessInfo.processInfo.environment["BRUTAL_DOOM_QA_QUIT"] == "hold"
            quitWatch = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
                guard let self, let running = self.process, running.isRunning else { timer.invalidate(); return }
                let held = GCController.controllers().contains { c in
                    guard let g = c.extendedGamepad else { return false }
                    return g.buttonMenu.isPressed && (g.buttonOptions?.isPressed ?? false)
                } || (qa && Date().timeIntervalSince(started) >= 3)
                if !held { self.quitSince = nil; return }
                if self.quitSince == nil { self.quitSince = Date(); return }
                if Date().timeIntervalSince(self.quitSince!) >= 1.5 { self.quitRequested = true; running.terminate(); timer.invalidate() }
            }
            window.orderOut(nil); NSApp.hide(nil)
        } catch { showError(error) }
    }
    func showError(_ error: Error) { NSAlert(error: error).runModal() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { process == nil }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let p = process, p.isRunning { NSRunningApplication(processIdentifier: p.processIdentifier)?.activate(options: []); return .terminateCancel }
        return .terminateNow
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let p = process, p.isRunning { NSRunningApplication(processIdentifier: p.processIdentifier)?.activate(options: []) }
        else { window?.makeKeyAndOrderFront(nil) }
        return true
    }
}
let app = NSApplication.shared
let launcher = Launcher()
app.delegate = launcher
app.run()
