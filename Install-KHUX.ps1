$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'KHUX-Preservation'
$cache = Join-Path $root 'Downloads'
function Download-File($url, $path, $sha1) {
    if ((Test-Path -LiteralPath $path) -and $sha1 -and ((Get-FileHash -LiteralPath $path -Algorithm SHA1).Hash -eq $sha1)) { return }
    $partial = $path + '.partial'
    Write-Host "Downloading $([IO.Path]::GetFileName($path)) ..."
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source --fail --location --retry 4 --output $partial $url
        if ($LASTEXITCODE -ne 0) { throw 'Download failed. Run setup again to retry.' }
    } else { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $partial }
    if ($sha1 -and ((Get-FileHash -LiteralPath $partial -Algorithm SHA1).Hash -ne $sha1)) { throw "Checksum mismatch: $path. Run setup again." }
    Move-Item -LiteralPath $partial -Destination $path -Force
}
function Expand-Safe($zip, $destination) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $prefix = [IO.Path]::GetFullPath($destination).TrimEnd('\') + '\'
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($entry in $archive.Entries) {
            $target = [IO.Path]::GetFullPath((Join-Path $destination $entry.FullName))
            if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe archive path.' }
        }
    } finally { $archive.Dispose() }
    Expand-Archive -LiteralPath $zip -DestinationPath $destination -Force
}
try {
    Write-Host 'KINGDOM HEARTS UX Theater + Dark Road - Windows setup' -ForegroundColor Cyan
    Write-Host 'Downloads about 2.5 GB. Allow 10 GB free for setup and browser import.'
    Write-Host "Install folder: $root"
    New-Item -ItemType Directory -Force $root, $cache, (Join-Path $root 'v1') | Out-Null
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root))
    if ($drive.AvailableFreeSpace -lt 10GB) { throw 'Please free at least 10 GB on the installation drive and rerun setup.' }
    Download-File 'https://archive.org/download/khux-5.0.1-ww-web/v1/index.html' (Join-Path $root 'v1\index.html') 'eaff073653313688ee49107728a629803d42bafe'
    $contentZip = Join-Path $cache 'Content.zip'
    Download-File 'https://archive.org/download/khux-5.0.1-ww-web/Content.zip' $contentZip '818f4cb61d7a6cd2ce75cc3e74a7311d336a448e'
    Write-Host 'Extracting game files ...'
    Expand-Safe $contentZip $root
    $content = Join-Path $root 'Content'
    foreach ($file in @('main.76.com.square_enix.android_googleplay.khuxww.obb','patch.87.com.square_enix.android_googleplay.khuxww.obb','extra.mp4')) {
        if (-not (Test-Path -LiteralPath (Join-Path $content $file))) { throw "Missing game content: $file" }
    }
    $browser = Join-Path $root 'Browser\chrome-win64\chrome.exe'
    if (-not (Test-Path -LiteralPath $browser)) {
        Write-Host 'Getting official standalone Google Chrome ...'
        $release = Invoke-RestMethod 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json'
        $url = ($release.channels.Stable.downloads.chrome | Where-Object platform -eq 'win64').url
        if (-not $url.StartsWith('https://storage.googleapis.com/chrome-for-testing-public/')) { throw 'Unexpected Chrome download source.' }
        $browserZip = Join-Path $cache 'chrome-win64.zip'
        Download-File $url $browserZip $null
        Expand-Safe $browserZip (Join-Path $root 'Browser')
    }
    if (-not (Test-Path -LiteralPath $browser)) { throw 'Chrome extraction did not finish.' }
    # Allow Chrome's restricted sandbox to read its own executable files.
    & icacls.exe (Join-Path $root 'Browser') /grant '*S-1-15-2-1:(OI)(CI)(RX)' '*S-1-15-2-2:(OI)(CI)(RX)' /T /Q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure read access for the Chrome sandbox.' }
    $profile = Join-Path $root 'GameProfile'
    $index = Join-Path $root 'v1\index.html'
    $arguments = '--user-data-dir="' + $profile + '" --no-first-run --no-default-browser-check "' + $index + '"'
    $shell = New-Object -ComObject WScript.Shell
    $shortcutName = 'KINGDOM HEARTS UX + Dark Road.lnk'
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop $shortcutName
    if (Test-Path -LiteralPath $shortcutPath) {
        $existing = $shell.CreateShortcut($shortcutPath)
        if ($existing.TargetPath -ne $browser) { $shortcutPath = Join-Path $desktop 'KINGDOM HEARTS UX + Dark Road - Installer.lnk' }
    }
    if (Test-Path -LiteralPath $shortcutPath) {
        if ($shell.CreateShortcut($shortcutPath).TargetPath -ne $browser) { throw 'A different shortcut already uses the setup name; existing shortcut preserved.' }
    }
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $browser
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $root
    $shortcut.Save()
    Copy-Item -LiteralPath $shortcutPath -Destination (Join-Path $root $shortcutName) -Force
    $guide = @"
FIRST RUN
Click Choose Files / Game folder on the game page.
Paste this folder path into the folder picker's address bar, press Enter,
then choose Upload / Select Folder:

$content

Wait for the local browser import to finish. On later visits, use the desktop shortcut.
Dark Road is playable. Union chi is Theater Mode/avatar customization, not
the original live-service gameplay. The archive includes gameplay patches:
title version changes, increased level stat bonuses, and enemy-kill requirements.
Keep $profile intact: it holds your imported content and saves.
Close Chrome before backing up the installation folder. Do not clear site data.
The standalone browser does not auto-update; use it for this local game only.
Source: https://archive.org/details/khux-5.0.1-ww-web
Tracker: https://qqclutchyqq.github.io/khux-theater-tracker/
"@
    $guidePath = Join-Path $root 'FIRST RUN.txt'
    Set-Content -LiteralPath $guidePath -Value $guide -Encoding UTF8
    Write-Host 'Setup complete. Your desktop shortcut is ready.' -ForegroundColor Green
    Write-Host "Choose this folder in the game: $content"
    Start-Process notepad.exe -ArgumentList ('"' + $guidePath + '"')
    Start-Process -FilePath $browser -ArgumentList $arguments
} catch {
    Write-Host "Setup stopped: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Existing GameProfile and saves are preserved. Fix the issue and rerun setup.'
    exit 1
}
