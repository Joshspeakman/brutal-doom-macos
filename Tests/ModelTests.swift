import Foundation

@main struct ModelTests {
    static func main() throws {
        var ini = IniFile(text: "; Keep this comment\n[GlobalSettings]\nvid_maxfps=137\ncustom=value\n[Chex.ConsoleVariables]\ngl_bloom=false\n[Chex.Bindings]\nQ=kickem\n[Chex.LocalServerInfo.Mod]\ncustom_mod=99\n")
        ini.set(section: "GlobalSettings", key: "vid_maxfps", value: "120")
        ini.set(section: "Chex.ConsoleVariables", key: "gl_bloom", value: "true")
        ini.set(section: "GlobalSettings", key: "gl_ssao", value: "2")
        ini.set(section: "Missing.Section", key: "new", value: "yes")
        precondition(ini.value(section: "GlobalSettings", key: "vid_maxfps") == "120")
        precondition(ini.value(section: "GlobalSettings", key: "gl_ssao") == "2")
        precondition(ini.value(section: "Chex.ConsoleVariables", key: "gl_bloom") == "true")
        precondition(ini.value(section: "Chex.Bindings", key: "Q") == "kickem")
        precondition(ini.value(section: "Chex.LocalServerInfo.Mod", key: "custom_mod") == "99")
        precondition(ini.value(section: "Missing.Section", key: "new") == "yes")
        precondition(ini.text.contains("; Keep this comment") && ini.text.contains("custom=value"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try ini.text.write(to: root.appendingPathComponent("Defaults.ini"), atomically: true, encoding: .utf8)
        let game = Game(id: "chex", title: "Chex", version: "test", description: "", controls: "", iwad: "IWADs/chex.wad", profile: "Chex Test", defaults: "Defaults.ini", mods: ["Mods/base.pk3", "Mods/patch.pk3"])
        let store = CollectionStore(base: root)
        try store.update(graphicsSettings[1], value: "false", game: game)
        let result = try store.config(game)
        precondition(result.value(section: "GlobalSettings", key: "gl_lights") == "false")
        precondition(result.value(section: "GlobalSettings", key: "r_dynlights") == "false")
        precondition(result.value(section: "Chex.Bindings", key: "Q") == "kickem")
        let defaults = try String(contentsOf: root.appendingPathComponent("Defaults.ini"), encoding: .utf8)
        precondition(defaults == ini.text)
        let args = try store.arguments(game)
        precondition(args[3...4] == [root.appendingPathComponent("Mods/base.pk3").path, root.appendingPathComponent("Mods/patch.pk3").path])
        precondition(args.contains(root.appendingPathComponent("Profiles/Chex Test/Saves").path))
        do { _ = try store.path("../escape"); fatalError("Path escaped collection") } catch {}
        print("PASS: settings preserve bindings and mod sections; defaults remain unchanged; profile paths and mod order are isolated.")
    }
}
