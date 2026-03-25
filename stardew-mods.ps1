# Stardew Valley Mod Setup and Launcher - Windows (Steam)
# Usage:
#   powershell -ExecutionPolicy Bypass -File stardew-mods.ps1 setup
#   powershell -ExecutionPolicy Bypass -File stardew-mods.ps1 play

$ErrorActionPreference = "Stop"
$GDRIVE_FILE_ID = "1BLXVLp_l_fi-p6-0aDJ9_4pKGa9XAeDc"

function Log  { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Ok   { param($msg) Write-Host "[ OK ]  $msg" -ForegroundColor Green }
function Warn { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }

function Err {
    param($msg)
    Write-Host "[ERR]  $msg" -ForegroundColor Red
    exit 1
}

function Find-Game {
    $defaultPath = 'C:\Program Files (x86)\Steam\steamapps\common\Stardew Valley'
    if (Test-Path $defaultPath) { return $defaultPath }

    $vdfPath = 'C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf'
    if (Test-Path $vdfPath) {
        $content = Get-Content $vdfPath -Raw
        $regMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
        foreach ($m in $regMatches) {
            $altPath = Join-Path $m.Groups[1].Value 'steamapps\common\Stardew Valley'
            if (Test-Path $altPath) { return $altPath }
        }
    }

    Warn 'Could not find Stardew Valley automatically.'
    $manual = Read-Host 'Enter the full path to your Stardew Valley folder'
    if (Test-Path $manual) { return $manual }
    Err "Path not found: $manual"
}

function Cmd-Setup {
    Write-Host ''
    Write-Host 'Stardew Valley Mod Setup - Windows' -ForegroundColor Cyan
    Write-Host '=========================================='

    Log 'Looking for Stardew Valley...'
    $gameDir = Find-Game
    $modsDir = Join-Path $gameDir 'Mods'
    Ok "Found at: $gameDir"

    Log 'Checking for SMAPI...'
    $smapiExe = Join-Path $gameDir 'StardewModdingAPI.exe'

    if (Test-Path $smapiExe) {
        Ok 'SMAPI is already installed'
    }
    else {
        Log 'Downloading latest SMAPI...'
        $tmpDir = Join-Path $env:TEMP ('stardew_setup_' + (Get-Random))
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

        $releaseJson = Invoke-RestMethod -Uri 'https://api.github.com/repos/Pathoschild/SMAPI/releases/latest'
        $asset = $releaseJson.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
        if (-not $asset) { Err 'Could not find SMAPI download URL. Install manually from https://smapi.io' }
        $smapiUrl = $asset.browser_download_url

        $outerZip = Join-Path $tmpDir 'smapi_outer.zip'
        Log "Downloading from: $smapiUrl"
        Invoke-WebRequest -Uri $smapiUrl -OutFile $outerZip -UseBasicParsing

        $outerExtract = Join-Path $tmpDir 'smapi_outer'
        Expand-Archive -Path $outerZip -DestinationPath $outerExtract -Force

        $innerZip = Get-ChildItem -Path $outerExtract -Filter '*.zip' -Recurse | Select-Object -First 1
        if ($innerZip) {
            Log 'Extracting inner SMAPI installer...'
            $smapiDir = Join-Path $tmpDir 'smapi'
            Expand-Archive -Path $innerZip.FullName -DestinationPath $smapiDir -Force
        }
        else {
            $smapiDir = $outerExtract
        }

        $installer = Get-ChildItem -Path $smapiDir -Filter 'install on Windows.bat' -Recurse | Select-Object -First 1
        if ($installer) {
            Log 'Running SMAPI installer...'
            Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c "' + $installer.FullName + '"') -Wait
            Ok 'SMAPI installed - follow any prompts that appeared'
        }
        else {
            Warn 'Could not find SMAPI installer automatically.'
            Write-Host "  SMAPI extracted to: $smapiDir" -ForegroundColor Yellow
            Write-Host '  Run install on Windows.bat from that folder manually.'
            Read-Host 'Press Enter after installing SMAPI'
        }

        if (Test-Path $smapiExe) {
            Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path $modsDir)) {
        New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
    }

    $gdownCmd = Get-Command gdown -ErrorAction SilentlyContinue
    if (-not $gdownCmd) {
        Log 'Installing gdown...'
        $ErrorActionPreference = 'Continue'
        & pip install gdown 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'

        # Add Python Scripts to PATH for this session
        $pyScripts = Join-Path $env:APPDATA 'Python\Python314\Scripts'
        if (Test-Path $pyScripts) {
            $env:PATH = $pyScripts + ';' + $env:PATH
        }
        # Also check common Python paths
        $pyScripts2 = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python314\Scripts'
        if (Test-Path $pyScripts2) {
            $env:PATH = $pyScripts2 + ';' + $env:PATH
        }
        # Try any Python version
        $pyDirs = Get-ChildItem -Path (Join-Path $env:APPDATA 'Python') -Directory -ErrorAction SilentlyContinue
        foreach ($d in $pyDirs) {
            $s = Join-Path $d.FullName 'Scripts'
            if (Test-Path $s) { $env:PATH = $s + ';' + $env:PATH }
        }
        $pyDirs2 = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Programs\Python') -Directory -ErrorAction SilentlyContinue
        foreach ($d in $pyDirs2) {
            $s = Join-Path $d.FullName 'Scripts'
            if (Test-Path $s) { $env:PATH = $s + ';' + $env:PATH }
        }

        $gdownCmd = Get-Command gdown -ErrorAction SilentlyContinue
        if (-not $gdownCmd) {
            Err 'gdown installed but not found on PATH. Close and reopen PowerShell, then run setup again.'
        }
        Ok 'gdown installed'
    }

    Log 'Downloading mod pack from Google Drive...'
    $tmpDir2 = Join-Path $env:TEMP ('stardew_mods_' + (Get-Random))
    New-Item -ItemType Directory -Path $tmpDir2 -Force | Out-Null
    $zipPath = Join-Path $tmpDir2 'mods.zip'

    & gdown "https://drive.google.com/uc?id=$GDRIVE_FILE_ID" -O $zipPath
    if (-not (Test-Path $zipPath)) { Err 'Download failed.' }
    Ok 'Download complete'

    $existingMods = Get-ChildItem -Path $modsDir -Directory -ErrorAction SilentlyContinue
    if ($existingMods -and $existingMods.Count -gt 0) {
        $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupDir = $modsDir + '_backup_' + $ts
        Warn "Backing up existing mods to: $backupDir"
        Copy-Item -Path $modsDir -Destination $backupDir -Recurse
    }

    Log 'Clearing old mods...'
    Get-ChildItem -Path $modsDir -Directory | Where-Object {
        $_.Name -ne 'ConsoleCommands' -and $_.Name -ne 'SaveBackup'
    } | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force
    }

    Log 'Extracting mods...'
    $extractDir = Join-Path $tmpDir2 'mods_extracted'
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $manifests = Get-ChildItem -Path $extractDir -Filter 'manifest.json' -Recurse -Depth 6
    foreach ($manifest in $manifests) {
        $modFolder = $manifest.Directory
        $modName = $modFolder.Name
        $destPath = Join-Path $modsDir $modName
        Copy-Item -Path $modFolder.FullName -Destination $destPath -Recurse -Force
        Ok "Installed: $modName"
    }

    Write-Host ''
    Write-Host 'Setup complete!' -ForegroundColor Green
    Write-Host '--------------------------------------'
    Write-Host "  Game:  $gameDir" -ForegroundColor Cyan
    Write-Host "  Mods:  $modsDir" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Installed mods:'
    Get-ChildItem -Path $modsDir -Directory | Sort-Object Name | ForEach-Object {
        Write-Host "    + $($_.Name)" -ForegroundColor Green
    }
    Write-Host ''
    Write-Host '  To play: powershell -ExecutionPolicy Bypass -File stardew-mods.ps1 play' -ForegroundColor White
    Write-Host ''

    Remove-Item -Path $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
}

function Cmd-Play {
    $gameDir = Find-Game
    $modsDir = Join-Path $gameDir 'Mods'

    Write-Host ''
    Write-Host '  Stardew Valley Launcher' -ForegroundColor White
    Write-Host '  -----------------------'
    Write-Host '  1 - Vanilla, no mods'
    Write-Host '  2 - Modded, SMAPI + mods'
    Write-Host ''
    $choice = Read-Host '  Choose [1/2]'

    if ($choice -eq '2') {
        $smapiExe = Join-Path $gameDir 'StardewModdingAPI.exe'
        if (Test-Path $smapiExe) {
            Write-Host 'Launching with SMAPI...'
            Start-Process -FilePath $smapiExe -WorkingDirectory $gameDir
        }
        else {
            Err 'SMAPI not found. Run setup first.'
        }
    }
    else {
        Write-Host 'Launching vanilla Stardew Valley...'
        Start-Process 'steam://rungameid/413150'
    }
}

$command = ''
if ($args.Count -gt 0) { $command = $args[0] }

if ($command -eq 'setup') { Cmd-Setup }
elseif ($command -eq 'play') { Cmd-Play }
else {
    Write-Host ''
    Write-Host 'Stardew Valley Mod Manager' -ForegroundColor White
    Write-Host ''
    Write-Host '  Usage:'
    Write-Host '    powershell -ExecutionPolicy Bypass -File stardew-mods.ps1 setup   Install SMAPI + mods'
    Write-Host '    powershell -ExecutionPolicy Bypass -File stardew-mods.ps1 play    Launch vanilla or modded'
    Write-Host ''
}
