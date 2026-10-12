from pathlib import Path
import sys,shutil,subprocess,plistlib,os,json
root=Path(__file__).resolve().parent.parent
base=Path(sys.argv[1]).expanduser().resolve(); apps=Path(sys.argv[2]).expanduser().resolve()
apps.mkdir(parents=True,exist_ok=True)
# Append new built-in choices without replacing custom entries or existing choices.
catalog=base/'Games.json'
if catalog.exists():
 current=json.loads(catalog.read_text())
 known={game['id'] for game in current}
 additions=[game for game in json.loads((root/'catalog/Games.json').read_text()) if game['id'] not in known]
 if additions:
  staged=catalog.with_suffix('.json.new')
  staged.write_text(json.dumps(current+additions,indent=2,ensure_ascii=False)+'\n')
  staged.replace(catalog)
for src in (root/'catalog').rglob('*'):
 if src.is_file():
  dst=base/src.relative_to(root/'catalog')
  if not dst.exists():dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
if not (base/'START HERE.txt').exists():
 (base/'START HERE.txt').write_text('Open Brutal Doom.app. Choose a game and Play.\nDisplay and Graphics save per-game settings. Controls lists starting keys.\nFiles opens saves and this guide. Each game has a separate Profiles folder.\n\nSetup and mod source documentation:\nhttps://github.com/Joshspeakman/brutal-doom-macos/blob/nightly/README.md\n')
# The collection works without banner art when some optional games are missing.
result=subprocess.run([sys.executable,str(root/'tools/extract_art.py'),str(base),str(base/'LauncherArt')],capture_output=True,text=True)
if result.returncode:print('Some banner art could not be extracted; missing art uses the drawn theme.')
dest=apps/'Brutal Doom.app';stage=apps/'.Brutal Doom.installing.app'
if stage.exists():shutil.rmtree(stage)
subprocess.run(['ditto',str(root/'build/Brutal Doom.app'),str(stage)],check=True)
# Retain the existing local icon, if present.
icon=dest/'Contents/Resources/BrutalDoom.icns'
info=stage/'Contents/Info.plist';meta=plistlib.loads(info.read_bytes())
if icon.exists():
 shutil.copy2(icon,stage/'Contents/Resources/BrutalDoom.icns');meta['CFBundleIconFile']='BrutalDoom.icns'
meta['BrutalDoomDataDirectory']=str(base)
info.write_bytes(plistlib.dumps(meta))
subprocess.run(['codesign','--force','--sign','-',str(stage)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(stage)],check=True)
backup=apps/'.Brutal Doom.previous.app'
if backup.exists():shutil.rmtree(backup)
if dest.exists():os.rename(dest,backup)
try:os.rename(stage,dest)
except BaseException:
 if backup.exists():os.rename(backup,dest)
 raise
print('Installed',dest)
