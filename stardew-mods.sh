#!/bin/bash
set -e

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()   { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

# ── Config ───────────────────────────────────────────────────
GDRIVE_FILE_ID="1BLXVLp_l_fi-p6-0aDJ9_4pKGa9XAeDc"
STEAM_DIR="$HOME/Library/Application Support/Steam/steamapps/common/Stardew Valley"

# ── Find game ────────────────────────────────────────────────
find_game() {
    GAME_DIR=""
    if [ -d "$STEAM_DIR" ]; then
        GAME_DIR="$STEAM_DIR"
    else
        VDF="$HOME/Library/Application Support/Steam/steamapps/libraryfolders.vdf"
        if [ -f "$VDF" ]; then
            while IFS= read -r line; do
                if [[ "$line" =~ \"path\"[[:space:]]+\"(.+)\" ]]; then
                    alt="${BASH_REMATCH[1]}/steamapps/common/Stardew Valley"
                    [ -d "$alt" ] && GAME_DIR="$alt" && break
                fi
            done < "$VDF"
        fi
    fi

    if [ -z "$GAME_DIR" ]; then
        warn "Could not find Stardew Valley automatically."
        read -rp "Enter the full path to your Stardew Valley folder: " GAME_DIR
        [ -d "$GAME_DIR" ] || err "Path not found: $GAME_DIR"
    fi

    SMAPI_DIR="$GAME_DIR/Contents/MacOS"
    MODS_DIR="$SMAPI_DIR/Mods"
}

# ── Setup command ────────────────────────────────────────────
cmd_setup() {
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    echo ""
    echo -e "${BOLD}${CYAN}Stardew Valley Mod Setup — macOS${NC}"
    echo "════════════════════════════════════════"

    # 1. Find game
    log "Looking for Stardew Valley..."
    find_game
    ok "Found at: $GAME_DIR"

    # 2. Install SMAPI
    log "Checking for SMAPI..."
    if [ -f "$SMAPI_DIR/StardewModdingAPI" ] || [ -f "$SMAPI_DIR/StardewModdingAPI.dll" ]; then
        ok "SMAPI is already installed"
    else
        log "Downloading latest SMAPI..."
        RELEASE_JSON=$(curl -sL "https://api.github.com/repos/Pathoschild/SMAPI/releases/latest")
        SMAPI_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": "[^"]*\.zip"' | grep -o 'https://[^"]*' | head -1)
        [ -z "$SMAPI_URL" ] && err "Could not find SMAPI download URL. Install manually from https://smapi.io"

        curl -L "$SMAPI_URL" -o "$TMP_DIR/smapi_outer.zip" --progress-bar
        unzip -q "$TMP_DIR/smapi_outer.zip" -d "$TMP_DIR/smapi_outer"

        # SMAPI ships as a zip-inside-a-zip
        INNER_ZIP=$(find "$TMP_DIR/smapi_outer" -name "*.zip" | head -1)
        if [ -n "$INNER_ZIP" ]; then
            log "Extracting SMAPI installer..."
            unzip -q "$INNER_ZIP" -d "$TMP_DIR/smapi"
        else
            mv "$TMP_DIR/smapi_outer" "$TMP_DIR/smapi"
        fi

        xattr -cr "$TMP_DIR/smapi" 2>/dev/null || true

        INSTALLER=$(find "$TMP_DIR/smapi" -name "install on macOS.command" -o -name "install on macOS.sh" | head -1)
        if [ -n "$INSTALLER" ]; then
            log "Running SMAPI installer..."
            bash "$INSTALLER" --game-path "$GAME_DIR" --no-prompt 2>/dev/null || \
            bash "$INSTALLER" -- --game-path "$GAME_DIR" --no-prompt
            ok "SMAPI installed"
        else
            err "Could not find SMAPI installer. Install manually from https://smapi.io"
        fi
    fi

    # 3. Create Mods folder
    mkdir -p "$MODS_DIR"

    # 4. Install gdown if needed
    if ! command -v gdown &>/dev/null; then
        log "Installing gdown (Google Drive downloader)..."
        pip3 install --break-system-packages --quiet gdown 2>/dev/null || \
        pip3 install --quiet gdown 2>/dev/null || \
        err "Could not install gdown. Run: pip3 install gdown"
        ok "gdown installed"
    fi

    # 5. Download mods from Google Drive
    log "Downloading mod pack from Google Drive..."
    ZIP_PATH="$TMP_DIR/mods.zip"
    gdown "https://drive.google.com/uc?id=$GDRIVE_FILE_ID" -O "$ZIP_PATH"
    file "$ZIP_PATH" | grep -qi "zip" || err "Download failed — not a zip. Make sure the Drive link is set to 'Anyone with the link'."
    ok "Download complete"

    # 6. Backup existing mods & extract
    if [ "$(ls -A "$MODS_DIR" 2>/dev/null)" ]; then
        BACKUP="${MODS_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        warn "Backing up existing mods to: $BACKUP"
        cp -r "$MODS_DIR" "$BACKUP"
    fi

    # Clear existing mods (keep SMAPI built-ins) to prevent duplicates
    log "Clearing old mods..."
    find "$MODS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "ConsoleCommands" ! -name "SaveBackup" -exec rm -rf {} +

    log "Extracting mods..."
    unzip -q "$ZIP_PATH" -d "$TMP_DIR/mods_extracted"
    xattr -cr "$TMP_DIR/mods_extracted" 2>/dev/null || true

    # Find every folder containing a manifest.json (these are actual SMAPI mods)
    # and copy them into the Mods directory
    find "$TMP_DIR/mods_extracted" -name "manifest.json" -maxdepth 6 | while read -r manifest; do
        MOD_FOLDER=$(dirname "$manifest")
        MOD_NAME=$(basename "$MOD_FOLDER")
        cp -r "$MOD_FOLDER" "$MODS_DIR/$MOD_NAME"
        ok "Installed: $MOD_NAME"
    done

    xattr -cr "$MODS_DIR" 2>/dev/null || true

    # 7. Summary
    echo ""
    echo -e "${BOLD}${GREEN}Setup complete!${NC}"
    echo "────────────────────────────────────────"
    echo -e "  Game:  ${CYAN}$GAME_DIR${NC}"
    echo -e "  Mods:  ${CYAN}$MODS_DIR${NC}"
    echo ""
    echo "  Installed mods:"
    find "$MODS_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r d; do
        echo -e "    ${GREEN}✓${NC} $(basename "$d")"
    done
    echo ""
    echo -e "  ${BOLD}To play, run:${NC}  bash ~/stardew-mods.sh play"
    echo -e "  If mods are blocked by macOS, run: ${YELLOW}xattr -cr \"$MODS_DIR\"${NC}"
    echo ""
}

# ── Play command ─────────────────────────────────────────────
cmd_play() {
    find_game

    echo ""
    echo -e "  ${BOLD}Stardew Valley Launcher${NC}"
    echo "  ───────────────────────"
    echo "  1) Vanilla (no mods)"
    echo "  2) Modded (SMAPI + mods)"
    echo ""
    read -rp "  Choose [1/2]: " choice

    case "$choice" in
        2)
            if [ -f "$SMAPI_DIR/StardewModdingAPI" ]; then
                echo "Launching with SMAPI..."
                cd "$SMAPI_DIR"
                ./StardewModdingAPI
            elif [ -f "$SMAPI_DIR/StardewModdingAPI.dll" ]; then
                echo "Launching with SMAPI (.NET)..."
                cd "$SMAPI_DIR"
                dotnet StardewModdingAPI.dll
            else
                err "SMAPI not found. Run: bash ~/stardew-mods.sh setup"
            fi
            ;;
        *)
            echo "Launching vanilla Stardew Valley..."
            open "steam://rungameid/413150"
            ;;
    esac
}

# ── Main ─────────────────────────────────────────────────────
case "${1:-}" in
    setup)
        cmd_setup
        ;;
    play)
        cmd_play
        ;;
    *)
        echo ""
        echo -e "${BOLD}Stardew Valley Mod Manager${NC}"
        echo ""
        echo "  Usage:"
        echo "    bash stardew-mods.sh setup   Install SMAPI + mods (run once)"
        echo "    bash stardew-mods.sh play    Launch vanilla or modded"
        echo ""
        ;;
esac
