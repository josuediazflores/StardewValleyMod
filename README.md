# Stardew Valley Mod Setup

One-command setup for a curated Stardew Valley mod pack on **macOS** and **Windows** (Steam).

Installs [SMAPI](https://smapi.io) (the mod loader) and 89+ mods including Stardew Valley Expanded, Content Patcher, UI Info Suite 2, and more — then lets you choose between vanilla and modded gameplay each time you launch.

---

## Quick Start

### macOS

**1. Download the script**
```bash
curl -sL "https://raw.githubusercontent.com/josuediazflores/StardewValleyMod/main/stardew-mods.sh" -o ~/stardew-mods.sh && chmod +x ~/stardew-mods.sh
```

**2. Install SMAPI + mods (run once)**
```bash
bash ~/stardew-mods.sh setup
```

**3. Play**
```bash
bash ~/stardew-mods.sh play
```

### Windows

**1. Download the script** (open PowerShell)
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/josuediazflores/StardewValleyMod/main/stardew-mods.ps1" -OutFile "$HOME\stardew-mods.ps1"
```

**2. Install SMAPI + mods (run once)**
```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\stardew-mods.ps1" setup
```

**3. Play**
```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\stardew-mods.ps1" play
```

---

## What It Does

### `setup` command (run once)
1. **Finds Stardew Valley** — checks the default Steam install path, parses `libraryfolders.vdf` for alternate Steam libraries, or lets you enter the path manually
2. **Installs SMAPI** — downloads the latest release from GitHub, handles the zip-inside-a-zip packaging, and runs the platform-specific installer
3. **Installs gdown** — a Python tool for reliable Google Drive downloads (auto-installed via pip)
4. **Downloads the mod pack** — pulls the curated mod zip from Google Drive
5. **Backs up existing mods** — if you already have mods, they're copied to a timestamped backup folder
6. **Extracts and installs mods** — finds all valid SMAPI mods (by locating `manifest.json` files) and copies them into the correct Mods directory
7. **Strips macOS quarantine flags** (macOS only) — prevents Gatekeeper from blocking mod files

### `play` command (every time)
Presents a menu:
- **Option 1** — Launches vanilla Stardew Valley through Steam (no mods)
- **Option 2** — Launches the game with SMAPI, loading all installed mods

---

## Requirements

| | macOS | Windows |
|---|---|---|
| **Stardew Valley** | Steam version | Steam version |
| **Python 3** | Pre-installed on macOS | [python.org](https://www.python.org/downloads/) (check "Add to PATH") |
| **curl / unzip** | Pre-installed on macOS | N/A (PowerShell built-ins used) |

---

## Installed Mods

<details>
<summary>Click to expand full mod list (89 mods)</summary>

### Frameworks & Core
- Content Patcher
- Content Patcher Animations
- SpaceCore
- Generic Mod Config Menu
- Farm Type Manager (FTM)
- Mail Framework Mod
- Mapping Extensions and Extra Properties (MEEP)
- MistyCore
- StardewUI
- Item Extensions
- Dialogue Display Framework
- TrinketTinker
- Button's Extra Trigger Action Stuff (BETAS)
- Livestock Bazaar
- Custom Companions

### Major Content Mods
- Stardew Valley Expanded (SVE)
- Grampleton Fields
- Grandpa's Farm
- Frontier Farm
- Downhill Project (Main + NPCs + Extras)
- Buildable Ginger Island Farm
- Ginger Island Extra Locations - Redux
- Solarium at the Spa Revisited
- Additional Farm Cave

### UI & Quality of Life
- UI Info Suite 2
- Lookup Anything
- Chests Anywhere
- Better Crafting
- NPC Map Locations
- Schedule Viewer
- Automate
- Convenient Inventory
- Quest Helper
- Better Signs
- Mini Bars
- Social Page Order Redux
- Visible Fish
- World Maps
- MultiSave
- Relocate Buildings And Farm Animals
- Event Limiter
- Friends Forever
- Calendar Anniversary
- Part of the Community
- Sit for Stamina
- Faster Path Speed
- Font Settings
- SinZational Speedy Solutions
- ItsStardewTime
- Dynamic Reflections
- Unlockable Bundles

### Visual & Cosmetic
- Seasonal Cute Characters
- DaisyNiko's Tilesheets
- HxW Tilesheets
- Lumisteria Tilesheets (Indoor + Outdoor)
- Animated Clothes
- Animated Food and Drinks
- Animated Furniture and Stuff
- Animated Gemstones
- Animated Slime Eggs and Loot
- Cuter Slimes Refreshed
- Standardized Seed Sprites
- Seasonal Mariner To Mermaid
- Tiny Totem Statue Obelisks
- Plain Slime Hutch
- Remapping

### NPC & Dialogue
- Clint Reforged
- Marnie Deserves Better
- I Fixed Him Shane Mod
- Fippsie's Tidy Pam
- No Pam Enabling
- Spouses React To Death
- Community Center
- Portraits for Extras
- Portraits for Vendors
- Dialogue Display Tweaks

### Misc
- Add Berry Seasons to Calendar
- Seasonal Cute Characters SVE
- Stardew Valley Expanded Add-On (Schedule Viewer)

</details>

---

## Troubleshooting

### macOS: Mods blocked by Gatekeeper
```bash
xattr -cr "$HOME/Library/Application Support/Steam/steamapps/common/Stardew Valley/Contents/MacOS/Mods"
```

### Windows: SMAPI didn't install
The automated installer may close before you can interact with it. Install SMAPI manually:
1. Download from [smapi.io](https://smapi.io)
2. Extract the zip (it's a zip inside a zip)
3. Run `install on Windows.bat`
4. Pick your game path (usually option 1)
5. Then run `play` — the mods are already installed

### Windows: "gdown not found" after install
Close PowerShell, reopen it, and run `setup` again. Python's Scripts folder needs to be on PATH.

### Mods not loading
- Check the SMAPI log for errors: look for `SMAPI-latest.txt` in your game's error logs folder
- Upload the log to [smapi.io/log](https://smapi.io/log) for easy troubleshooting
- Make sure all mods are compatible with your Stardew Valley version at [smapi.io/mods](https://smapi.io/mods)

### Steam achievements not working
When launching via the `play` command (option 2), SMAPI runs outside of Steam so achievements won't track. To get achievements, launch through Steam directly — but note that SMAPI may have hooked into Steam's launch, so it may load mods either way.

---

## File Structure

```
macOS:   ~/Library/Application Support/Steam/steamapps/common/Stardew Valley/Contents/MacOS/Mods/
Windows: C:\Program Files (x86)\Steam\steamapps\common\Stardew Valley\Mods\
```

---

## License

These scripts are provided as-is. All mods belong to their respective authors — check individual mod pages on [NexusMods](https://www.nexusmods.com/stardewvalley) for licenses and credits.
