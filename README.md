# Stardew Mod Manager

A native macOS mod manager for Stardew Valley with Nexus Mods integration, modpack profiles, and a Stardew-themed UI.

[![Download for macOS](https://img.shields.io/github/v/release/josuediazflores/StardewValleyMod?label=Download%20for%20macOS&style=for-the-badge&color=5D8A3C)](https://github.com/josuediazflores/StardewValleyMod/releases/latest/download/Stardew.Mod.Manager.zip)

> **Requires macOS 14+** and [SMAPI](https://smapi.io) installed.

---

## Install

1. Click the **Download for macOS** button above
2. Unzip `Stardew Mod Manager.zip`
3. Drag `Stardew Mod Manager.app` to your Applications folder
4. Launch and enjoy — future updates install automatically from within the app

---

## Features

- **Manage mods** — Enable, disable, and delete mods with one click
- **Modpack profiles** — Save different mod configurations and switch between them instantly
- **Browse Nexus Mods** — Search trending, latest, and popular mods with infinite scroll
- **Install from Nexus URL** — Paste a mod link to auto-download and install
- **NXM protocol support** — Click "Download with Manager" on Nexus and it installs automatically
- **Import mods** — Drag & drop ZIP files or folders, or use the file picker
- **Share modpacks** — Export as `.smm` files or copy to clipboard for friends
- **Compare profiles** — See which mods differ between two profiles
- **Auto-updates** — Check for and install updates from within the app
- **Themed UI** — Stardew (golden) and Pink theme options
- **Mac App Store + Steam + GOG** — Auto-detects game path from any store

---

## Screenshots

*Coming soon*

---

## Building from Source

Requires Xcode Command Line Tools.

```bash
git clone https://github.com/josuediazflores/StardewValleyMod.git
cd StardewValleyMod
bash build-app.sh
open "build/Stardew Mod Manager.app"
```

---

## Scripts (Legacy)

The original shell/PowerShell scripts for one-command mod installation are still available:

<details>
<summary>macOS script</summary>

```bash
curl -sL "https://raw.githubusercontent.com/josuediazflores/StardewValleyMod/main/stardew-mods.sh" -o ~/stardew-mods.sh && chmod +x ~/stardew-mods.sh
bash ~/stardew-mods.sh setup
bash ~/stardew-mods.sh play
```
</details>

<details>
<summary>Windows script</summary>

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/josuediazflores/StardewValleyMod/main/stardew-mods.ps1" -OutFile "$HOME\stardew-mods.ps1"
powershell -ExecutionPolicy Bypass -File "$HOME\stardew-mods.ps1" setup
powershell -ExecutionPolicy Bypass -File "$HOME\stardew-mods.ps1" play
```
</details>

---

## License

Provided as-is. All mods belong to their respective authors — check individual mod pages on [NexusMods](https://www.nexusmods.com/stardewvalley) for licenses and credits.
