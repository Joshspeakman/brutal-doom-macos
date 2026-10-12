import Foundation

struct Game: Codable {
    let id, title, version, description, controls, iwad, profile, defaults: String
    let mods: [String]
    var configSection: String { (id.hasPrefix("chex") ? "Chex" : id == "hexen" ? "Hexen" : "Doom") + ".ConsoleVariables" }
    var shortTitle: String {
        switch id {
        case "doom": return "Doom"
        case "doom2": return "Doom II"
        case "chex": return "Chex Quest · Original"
        case "chex3": return "Chex Quest · Trilogy"
        case "wolfenstein": return "Wolfenstein 3D"
        case "doom64": return "Doom 64 · Veteran of Hell"
        case "hexen": return "Hexen RPG · Beta"
        case "schism": return "Schism · Four Heroes"
        case "projectbrutality": return "Project Brutality"
        case "pbmonsters": return "Brutal Doom · Expanded Monsters"
        case "aliens": return "Aliens · Eradication"
        case "lambda": return "Lambda · Half-Life Arsenal"
        default: return title
        }
    }
}
struct Setting {
    let title: String
    let key: String
    let values: [String]
    let labels: [String]
    let note: String
    let fallback: String
    var perGame = false
}
let displaySettings = [
    Setting(title: "SCREEN", key: "vid_fullscreen", values: ["true", "false"], labels: ["Full Screen", "Windowed"], note: "Choose how the game uses your display", fallback: "true"),
    Setting(title: "FRAME LIMIT", key: "vid_maxfps", values: ["60", "120", "144", "165", "240", "0"], labels: ["60 FPS", "120 FPS", "144 FPS", "165 FPS", "240 FPS", "Unlimited"], note: "An upper limit; actual frame rate depends on the game", fallback: "120"),
    Setting(title: "VERTICAL SYNC", key: "vid_vsync", values: ["true", "false"], labels: ["On", "Off"], note: "Synchronize frames with your display to prevent tearing", fallback: "true")
]
let graphicsSettings = [
    Setting(title: "TEXTURES", key: "gl_texture_filter", values: ["0", "4"], labels: ["Crisp", "Smooth"], note: "Original pixel edges or filtered textures", fallback: "0"),
    Setting(title: "DYNAMIC LIGHTS", key: "gl_lights", values: ["true", "false"], labels: ["On", "Off"], note: "Weapon flashes, lamps and other mod lighting", fallback: "true"),
    Setting(title: "BLOOM", key: "gl_bloom", values: ["false", "true"], labels: ["Off", "On"], note: "A soft glow around bright surfaces", fallback: "false", perGame: true),
    Setting(title: "AMBIENT SHADING", key: "gl_ssao", values: ["0", "1", "2", "3"], labels: ["Off", "Low", "Medium", "High"], note: "Adds depth around corners; higher levels cost performance", fallback: "0")
]

// Keep unrelated settings, bindings, comments and mod sections intact.
struct IniFile {
    var text: String
    func value(section: String, key: String) -> String? {
        var current = "", result: String?
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") { current = String(trimmed.dropFirst().dropLast()); continue }
            if current.caseInsensitiveCompare(section) == .orderedSame, let equals = line.firstIndex(of: "="),
               line[..<equals].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(key) == .orderedSame {
                result = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }
    mutating func set(section: String, key: String, value: String) {
        var lines = text.components(separatedBy: "\n"), current = "", sectionEnd: Int?, foundSection = false, changed = false
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                if current.caseInsensitiveCompare(section) == .orderedSame { sectionEnd = i }
                current = String(trimmed.dropFirst().dropLast())
                if current.caseInsensitiveCompare(section) == .orderedSame { foundSection = true; sectionEnd = nil }
                continue
            }
            if current.caseInsensitiveCompare(section) == .orderedSame, let equals = lines[i].firstIndex(of: "="),
               lines[i][..<equals].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(key) == .orderedSame {
                lines[i] = key + "=" + value; changed = true
            }
        }
        if !changed {
            if foundSection { lines.insert(key + "=" + value, at: sectionEnd ?? lines.count) }
            else { lines += ["", "[" + section + "]", key + "=" + value] }
        }
        text = lines.joined(separator: "\n")
        if !text.hasSuffix("\n") { text += "\n" }
    }
}

struct CollectionStore {
    let base: URL
    func path(_ relative: String) throws -> URL {
        let root = base.standardizedFileURL
        let url = root.appendingPathComponent(relative).standardizedFileURL
        guard !relative.hasPrefix("/"), url.path.hasPrefix(root.path + "/") else {
            throw NSError(domain: "BrutalDoom", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid game file path: \(relative)"])
        }
        return url
    }
    func configURL(_ game: Game) throws -> URL { try path("Profiles/" + game.profile + "/gzdoom.ini") }
    func config(_ game: Game) throws -> IniFile {
        let destination = try configURL(game)
        let source = FileManager.default.fileExists(atPath: destination.path) ? destination : try path(game.defaults)
        return IniFile(text: try String(contentsOf: source, encoding: .utf8))
    }
    func update(_ setting: Setting, value: String, game: Game) throws {
        guard setting.values.contains(value) else { return }
        var ini = try config(game)
        ini.set(section: setting.perGame ? game.configSection : "GlobalSettings", key: setting.key, value: value)
        if setting.key == "gl_lights" { ini.set(section: "GlobalSettings", key: "r_dynlights", value: value) }
        let destination = try configURL(game)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ini.text.write(to: destination, atomically: true, encoding: .utf8)
    }
    func arguments(_ game: Game) throws -> [String] {
        let profile = try path("Profiles/" + game.profile)
        return ["-iwad", try path(game.iwad).path, "-file"] + (try game.mods.map { try path($0).path }) +
            ["-config", try configURL(game).path, "-savedir", profile.appendingPathComponent("Saves").path,
             "-noautoload", "-noautoexec", "-stdout", "+screenshot_dir", profile.appendingPathComponent("Screenshots").path]
    }
}
