# Brutal Doom Collection for macOS

A native Apple Silicon launcher for a local GZDoom collection. Its game-art
banner, metal buttons, gold trim, arrow selectors and settings panels match
the other native Mac ports. It launches GZDoom directly; no Wine is used.

The launcher provides twelve game choices, per-game display and graphics
settings, a controls reference, save-folder shortcuts and a guide. It returns
after the game exits. Existing bindings and mod settings are preserved when
changing launcher settings.

## Requirements

- Apple Silicon Mac, macOS 11 or later.
- Xcode Command Line Tools (`xcode-select --install`) to build from source.
- The official [GZDoom 4.14.2 Mac app](https://github.com/ZDoom/gzdoom/releases/tag/g4.14.2).
- Your own required game data and the mods listed below.

The launcher, game engine and mods are separate projects. This repository
contains launcher source and initial configuration files. It contains no game
data, downloaded mods, extracted artwork, engine binaries, saves or keys.

## Prepare the collection

The default collection folder is `~/Games/Brutal Doom`. Put the official
GZDoom app at `Engine/GZDoom.app` inside it. Each entry requires these files,
with filenames and capitalization matching the table:

| Game | IWAD in `IWADs/` | Files loaded from `Mods/`, in order |
|---|---|---|
| Doom | `DOOM.WAD` | `brutalv21.pk3` |
| Doom II | `DOOM2.WAD` | `brutalv21.pk3` |
| Chex Quest Original | `chex.wad` | `brutalv21.pk3`, `Chex/cheques-07082020.pk3` |
| Chex Quest Trilogy | `chex3.wad` | `brutalv21.pk3`, `Chex/cheques-07082020.pk3` |
| Wolfenstein 3D | `DOOM2.WAD` | `Wolfenstein/ZMC-BWV7.2.pk3` |
| Doom 64 | `DOOM2.WAD` | `Doom64/BD64-VoH_game_v1.6.1.pk3`, `Doom64/BD64-VoH_maps_v1.6.1.pk3` |
| Hexen RPG | `HEXEN.WAD` | `Hexen/BrutalHexenRPG_V8.0_beta.pk3`, `Hexen/hexen_gz.pk3`, `Hexen/3_HEXEN64.wad` |
| Schism | `DOOM2.WAD` | `Schism/Schism_097D.pk3`, `Schism/Schism_097D_Patch.0.1_Public.pk3` |
| Project Brutality | `DOOM2.WAD` | `ProjectBrutality/Project_Brutality-0.4.1.pk3` |
| Brutal Doom: Expanded Monsters | `DOOM2.WAD` | `brutalv21.pk3`, `PBMonsters/bd21_pb-monsters.pk3` |
| Aliens: Eradication | `DOOM2.WAD` | `Aliens/ALIENS_ERADICATION_TC_2_0.pk3`, `Aliens/ERADICATION_MAPSET_2_0.wad` |
| Lambda: Half-Life Arsenal | `DOOM2.WAD` | `Lambda/Lambda_Resources.pk3`, `Lambda/Lambda_Code.pk3` |

Obtain game data from your own copies. The launcher does not download Steam
depots or authenticate to Steam. Only the selected entry's files are needed
to play it; unavailable entries report their missing files when launched.

Mod sources:

- [Brutal Doom v21 Gold](https://www.moddb.com/mods/brutal-doom/downloads/brutal-doom-v21-beta)
- [Chex compatibility patch, July 2020](https://www.moddb.com/mods/brutal-doom/downloads/brutal-doom-v21-chex-quest-patch)
- [Chex Quest 3 v1.4](https://www.chexquest3.com/downloads/)
- [ZioMcCall's Brutal Wolfenstein v7.2](https://www.moddb.com/mods/brutal-wolfenstein-3d/downloads/ziomccalls-brutal-wolfenstein-v72)
- [Brutal Doom 64: Veteran of Hell v1.6.1](https://www.moddb.com/mods/bd64-veteran-of-hell/downloads/bd64-veteran-of-hell)
- [Brutal Hexen RPG](https://www.moddb.com/mods/brutal-hexen), [author's ZDL Edition v8.0 beta download](https://nzdoom.net/showthread.php?tid=2)
- [Schism 0.97D](https://www.moddb.com/mods/schism1/downloads/schism-097d), [community patch 0.1](https://www.moddb.com/mods/schism1/downloads/schism-097d-patch-01)
- [Project Brutality 0.4.1](https://github.com/pa1nki113r/Project_Brutality/releases/tag/0.4.1). Package the contents inside the downloaded archive's top-level folder as the named PK3, with `ZSCRIPT.zc` and other mod files at the archive root.
- [Project Brutality Monsters for Brutal Doom v21 Gold](https://www.moddb.com/downloads/project-brutality-30-monsters-for-brutal-doom-v21-gold)
- [Aliens: Eradication TC 2.0](https://www.moddb.com/mods/aliens-eradication-tc/downloads/aliens-eradication-tc-20)
- Lambda: [resources](https://www.moddb.com/mods/lambda-for-doom-and-d00m-2/downloads/lambda-resources), [October 2023 code](https://www.moddb.com/mods/lambda-for-doom-and-d00m-2/downloads/lambda-code)

Keep these as separate entries: Wolfenstein, Doom 64 and Hexen do not load
Brutal Doom v21 on top of their own mods. The Chex compatibility patch loads
last. GZDoom autoload and autoexec files are disabled for these profiles.
Schism, Project Brutality, Aliens and Lambda also load independently of
Brutal Doom. Expanded Monsters loads Brutal Doom first, then its monster
add-on. Aliens includes its own campaign; the other new entries use Doom II.

## Install or update the launcher

```sh
git clone --branch nightly https://github.com/Joshspeakman/brutal-doom-macos.git
cd brutal-doom-macos
./install.sh
```

The installer builds and signs `~/Applications/Brutal Doom.app`, seeds missing
catalog/default files, and extracts banner artwork locally from your game
files. Artwork is optional; missing art falls back to the drawn theme.
Existing profiles, defaults and catalog entries are preserved. New built-in
entries are appended when their IDs are absent from the installed catalog.
A previous app
is retained as `.Brutal Doom.previous.app` in the chosen applications folder.

For a collection elsewhere:

```sh
BRUTAL_DOOM_DATA_DIR="/path/to/Brutal Doom" ./install.sh
```

`BRUTAL_DOOM_APP_DIR` optionally changes the application destination. The
installed app remembers its collection directory. To update source, use
`git pull --ff-only origin nightly` and run `./install.sh` again. This updates
the launcher; it does not replace GZDoom or the mods.

## Use

Use the arrows or click the game name to choose a game, then Play.

- **Display:** fullscreen/windowed, frame limit and VSync.
- **Graphics:** crisp/smooth textures, dynamic lights, bloom and ambient shading.
- **Controls:** starting bindings; customize them in the game's controls menu.
- **Files:** saves, collection folder and guide.

Display/graphics changes save immediately into the selected game's profile.
In-game settings are read again when the game closes. Profiles live under
`Profiles/<game>/` and contain `gzdoom.ini`, `Saves`, `Screenshots` and
`Last Run.log`. These are never stored in the app bundle or repository.

Hexen v8.0 is a beta. Select a weapon and familiar on its initial loadout
screen before playing. The [author's starter guide](https://nzdoom.net/showthread.php?tid=62)
uses different default keys; this launcher's Controls panel describes the
local starting keys. The Chex patch has known minor texture/message/sound
inconsistencies. The collection has first-map/save-load checks, not a complete
campaign playthrough; Hexen combat validation remains outstanding.

Schism offers four classes in New Game; F1 opens its class guide. Its release
is a test build with a community fixes patch. Aliens offers four classes
with different abilities and campaign events; press Use to skip its opening
briefing. Lambda defaults to its Half-Life HUD (`screenblocks=12`), and its
weapons reload with R. The older Expanded Monsters add-on has known missing
sprite/death-animation issues; it is kept separate from the original Doom
profiles. Project Brutality 0.4.1 is a tagged development release.

Brutal Half-Life v3 is a separate GoldSrc mod and is not a GZDoom package.
It is not a playable entry in this native collection: its distributed
client/server libraries are Windows x86 binaries, and matching native
libraries are still needed. A native Xash3D engine alone does not replace
the mod's custom game code.

## Build and validation

`./build.sh` runs the settings-preservation tests and builds an arm64 app.
The `nightly` branch also runs this in GitHub Actions and uploads a launcher
ZIP as a private Actions artifact. It contains no engine, artwork or games;
use the installer for a prepared collection. Builds are ad-hoc signed, not
Apple-notarized.

The local UI check covered game selection, settings changes, correct profile
and ordered mod arguments, and returning after a child process exits. The
model tests protect existing key bindings, unknown mod sections, initial
default files and separate save/config paths.

## License and credits

Launcher code is MIT licensed. Game and mod artwork remains owned by its
respective authors; `tools/extract_art.py` extracts it only on the local Mac.
GZDoom, the games and every mod retain their own licenses. This project is
not affiliated with their authors. Development used AI assistance.
