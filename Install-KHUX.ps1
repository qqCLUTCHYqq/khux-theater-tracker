param(
    [string]$InstallRoot = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'KHUX-Preservation'),
    [string]$DesktopPath = [Environment]::GetFolderPath('Desktop'),
    [switch]$NoLaunch, [switch]$Headless, [switch]$LibraryOnly, [string]$UiPreviewPath,
    [string]$LocalContent = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\Content.zip')
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not ('KhuxSetup.Downloader' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'Downloader.cs') }
$script:form = $null
$script:cancelRequested = $false
$script:logPath = $null
function Show-Status([string]$Text, [int]$Percent = -1) {
    if ($script:form) {
        $script:label.Text = $Text
        if ($Percent -ge 0) { $script:bar.Style = 'Continuous'; $script:bar.Value = [Math]::Min(100,$Percent) }
        else { $script:bar.Style = 'Marquee' }
        [Windows.Forms.Application]::DoEvents()
    } else { Write-Host $Text }
    if ($script:cancelRequested) { throw 'Setup paused. Run START SETUP.vbs again to resume.' }
}
function Write-Log([string]$Text) { if ($script:logPath) { Add-Content -LiteralPath $script:logPath -Value ((Get-Date).ToString('o') + ' ' + $Text) } }
function Download-File([string[]]$Sources,[string]$Path,[long]$Size,[string]$Sha256) {
    if ((Test-Path -LiteralPath $Path) -and $Sha256 -and ([KhuxSetup.Downloader]::Hash($Path) -eq $Sha256)) {
        Show-Status "Reusing verified $([IO.Path]::GetFileName($Path))."; return
    }
    $downloader = New-Object KhuxSetup.Downloader
    $downloader.Start($Sources,$Path,$Size,$Sha256)
    $timer = [Diagnostics.Stopwatch]::StartNew(); $lastTime = 0.0; $lastBytes = 0L; $rate = 0.0; $logged = 0
    try {
        while (-not $downloader.Done) {
            $elapsed = $timer.Elapsed.TotalSeconds
            if ($elapsed - $lastTime -ge 0.5) {
                $current = $downloader.NetworkBytes
                $instant = ($current - $lastBytes) / ($elapsed - $lastTime)
                if ($instant -gt 0) { if ($rate -eq 0) { $rate=$instant } else { $rate=.3*$instant+.7*$rate } }
                $lastTime=$elapsed; $lastBytes=$current
                $done=$downloader.Completed
                $remaining=[Math]::Max([long]0,[long]($Size-$done))
                $eta=if($rate -gt 0) { [TimeSpan]::FromSeconds($remaining/$rate).ToString('hh\:mm\:ss') } else { 'calculating' }
                $text=if($done -ge $Size) { $downloader.Status+"`r`nAll download bytes received." } else { "{0}`r`n{1:N1} / {2:N1} MB    {3:N2} MB/s    ETA {4}" -f $downloader.Status,($done/1MB),($Size/1MB),($rate/1MB),$eta }
                Show-Status $text ([int](100*$done/$Size))
            }
            if ($script:form) { [Windows.Forms.Application]::DoEvents() }
            if ($script:cancelRequested) { $downloader.Cancel() }
            Start-Sleep -Milliseconds 100
        }
    } catch { $downloader.Cancel(); throw }
    finally {
        # Wait briefly for aborted requests to flush before allowing the cache lock to close.
        while (-not $downloader.Done) { Start-Sleep -Milliseconds 100 }
        foreach($event in $downloader.Events) { Write-Log $event }
        Write-Log ("Download duration={0:N2}s networkBytes={1} retries={2} effectiveURL={3}" -f $timer.Elapsed.TotalSeconds,$downloader.NetworkBytes,$downloader.Retries,$downloader.EffectiveUrl)
    }
    if ($downloader.Error) { throw $downloader.Error }
}
function Expand-Preserved([string]$Zip,[string]$Destination,[string]$AllowedPrefix) {
    $archive=[IO.Compression.ZipFile]::OpenRead($Zip)
    $stage=Join-Path $cache ('extract-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    $entries=@()
    try {
        $prefix=[IO.Path]::GetFullPath($Destination).TrimEnd('\')+'\'
        foreach($entry in $archive.Entries) {
            $name=$entry.FullName.Replace('/','\')
            $target=[IO.Path]::GetFullPath((Join-Path $Destination $name))
            if (-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or $name.Contains(':') -or
                -not $name.StartsWith($AllowedPrefix+'\',[StringComparison]::OrdinalIgnoreCase)) { throw "Unexpected archive path: $name" }
            if ($name.EndsWith('\')) { continue }
            $entries+=@{ Entry=$entry; Name=$name; Target=$target }
        }
        $n=0
        foreach($item in $entries) {
            $n++; Show-Status "Checking and extracting files ($n / $($entries.Count))." ([int](100*$n/$entries.Count))
            $staged=Join-Path $stage $item.Name
            New-Item -ItemType Directory -Force ([IO.Path]::GetDirectoryName($staged)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($item.Entry,$staged,$false)
            if ((Get-Item -LiteralPath $staged).Length -ne $item.Entry.Length) { throw "Incomplete extraction: $($item.Name)" }
            if (Test-Path -LiteralPath $item.Target) {
                if ([KhuxSetup.Downloader]::Hash($item.Target) -ne [KhuxSetup.Downloader]::Hash($staged)) {
                    throw "Existing file differs: $($item.Target). It has been preserved. Use a separate installation folder to test."
                }
            }
        }
        # Only publish missing files after every entry has passed validation. No profile paths are accepted.
        foreach($item in $entries) {
            if (-not (Test-Path -LiteralPath $item.Target)) {
                New-Item -ItemType Directory -Force ([IO.Path]::GetDirectoryName($item.Target)) | Out-Null
                Move-Item -LiteralPath (Join-Path $stage $item.Name) -Destination $item.Target
            }
        }
    } finally {
        $archive.Dispose()
        # The generated staging path is verified to be directly beneath this install's cache.
        if ([IO.Path]::GetFullPath($stage).StartsWith([IO.Path]::GetFullPath($cache).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
function Ensure-Shortcut([string]$Browser,[string]$Arguments,[string]$Root,[string]$Desktop) {
    $shortcutPath=Join-Path $Desktop 'KINGDOM HEARTS UX + Dark Road.lnk'
    if (Test-Path -LiteralPath $shortcutPath) { Write-Log "Existing shortcut preserved unchanged: $shortcutPath"; return $shortcutPath }
    New-Item -ItemType Directory -Force $Desktop | Out-Null
    $shell=New-Object -ComObject WScript.Shell; $shortcut=$shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath=$Browser; $shortcut.Arguments=$Arguments; $shortcut.WorkingDirectory=$Root; $shortcut.Save()
    return $shortcutPath
}
function Test-InstalledContent([string]$Root) {
    $manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Content-manifest.json') -Raw | ConvertFrom-Json
    $complete=$true; $contentRoot=[IO.Path]::GetFullPath((Join-Path $Root 'Content')).TrimEnd('\')+'\'
    foreach($file in $manifest) {
        $target=[IO.Path]::GetFullPath((Join-Path $contentRoot $file.path))
        if(-not $target.StartsWith($contentRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid content manifest path.' }
        if(-not (Test-Path -LiteralPath $target)) { $complete=$false; continue }
        Show-Status "Verifying existing $($file.path)."
        if((Get-Item -LiteralPath $target).Length -ne $file.size -or [KhuxSetup.Downloader]::Hash($target) -ne $file.sha256) {
            throw "Existing file differs: $target. It has been preserved. Use a separate installation folder to test."
        }
    }
    return $complete
}
if ($LibraryOnly) { return }
$root=[IO.Path]::GetFullPath($InstallRoot); $cache=Join-Path $root 'Downloads'
$lock=$null
try {
    if (-not $Headless) {
        Add-Type -AssemblyName System.Windows.Forms,System.Drawing
        [Windows.Forms.Application]::EnableVisualStyles()
        $script:form=New-Object Windows.Forms.Form
        $script:form.Text='KINGDOM HEARTS UX + Dark Road - Setup 2.0.0'
        $script:form.Size=New-Object Drawing.Size(600,270); $script:form.StartPosition='CenterScreen'
        $script:form.FormBorderStyle='FixedDialog'; $script:form.MaximizeBox=$false
        $script:label=New-Object Windows.Forms.Label; $script:label.SetBounds(25,20,540,115)
        $script:label.Font=New-Object Drawing.Font('Segoe UI',11)
        $script:bar=New-Object Windows.Forms.ProgressBar; $script:bar.SetBounds(25,145,535,23)
        $button=New-Object Windows.Forms.Button; $button.Text='Pause setup'; $button.SetBounds(425,185,135,30)
        $button.Add_Click({$script:cancelRequested=$true})
        $script:form.Add_FormClosing({param($sender,$e) if(-not $script:finished) {$script:cancelRequested=$true;$e.Cancel=$true}})
        $script:form.Controls.AddRange(@($script:label,$script:bar,$button)); $script:form.Show()
    }
    New-Item -ItemType Directory -Force $root,$cache | Out-Null
    try { $lock=[IO.File]::Open((Join-Path $cache 'setup.lock'),'OpenOrCreate','ReadWrite','None') }
    catch { throw 'Another setup is using this folder. Close it before running setup again.' }
    $script:logPath=Join-Path $cache 'setup.log'
    Show-Status 'Checking existing files. Browser saves and profiles are preserved.'
    $index=Join-Path $root 'v1\index.html'
    $indexHash='4b93ed828aebc6b2eb15ab49489693ae9f7db4f77d867ca1fc0b46fb57e3a539'
    if ((Test-Path -LiteralPath $index) -and [KhuxSetup.Downloader]::Hash($index) -ne $indexHash) { throw 'Existing index.html differs from the original archive. It has been preserved. Test in a separate folder.' }
    $contentReady=Test-InstalledContent $root
    $browser=Join-Path $root 'Browser\chrome-win64\chrome.exe'
    $needsFiles=-not $contentReady -or -not (Test-Path -LiteralPath $index) -or -not (Test-Path -LiteralPath $browser)
    if ($needsFiles -and [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root)).AvailableFreeSpace -lt 10GB) { throw 'Please free at least 10 GB on the installation drive, then resume setup.' }
    Download-File @('https://ia601003.us.archive.org/23/items/khux-5.0.1-ww-web/v1/index.html','https://ia801003.us.archive.org/23/items/khux-5.0.1-ww-web/v1/index.html','https://archive.org/download/khux-5.0.1-ww-web/v1/index.html') $index 38803504 $indexHash
    $contentZip=Join-Path $cache 'Content.zip'
    $contentHash='b65eda4bafbd7a0a52cf8cf35cb77ed255cdea1cdc89a9a91850fbc28c13fdbf'
    if (-not $contentReady -and -not (Test-Path -LiteralPath $contentZip) -and (Test-Path -LiteralPath $LocalContent)) {
        Show-Status 'Verifying your existing Content.zip for reuse.'
        if ([KhuxSetup.Downloader]::Hash($LocalContent) -eq $contentHash) { Copy-Item -LiteralPath $LocalContent -Destination $contentZip; Write-Log 'Reused verified local Content.zip.' }
    }
    if (-not $contentReady) {
        Download-File @('https://ia601003.us.archive.org/23/items/khux-5.0.1-ww-web/Content.zip','https://ia801003.us.archive.org/23/items/khux-5.0.1-ww-web/Content.zip','https://archive.org/download/khux-5.0.1-ww-web/Content.zip') $contentZip 2244643150 $contentHash
        Expand-Preserved $contentZip $root 'Content'
        if(-not (Test-InstalledContent $root)) { throw 'Content verification did not finish.' }
    } else { Write-Log 'Verified existing content; skipped download and extraction.' }
    $content=Join-Path $root 'Content'
    foreach($name in @('main.76.com.square_enix.android_googleplay.khuxww.obb','patch.87.com.square_enix.android_googleplay.khuxww.obb','extra.mp4')) {
        if (-not (Test-Path -LiteralPath (Join-Path $content $name))) { throw "Missing archive file: $name" }
    }
    if (-not (Test-Path -LiteralPath $browser)) {
        Show-Status 'Getting the official standalone Chrome browser.'
        $release=Invoke-RestMethod 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json' -TimeoutSec 30
        $url=($release.channels.Stable.downloads.chrome | Where-Object platform -eq 'win64').url
        if (-not $url.StartsWith('https://storage.googleapis.com/chrome-for-testing-public/')) { throw 'Unexpected browser source.' }
        $browserZip=Join-Path $cache ('chrome-'+$release.channels.Stable.version+'.zip')
        $head=Invoke-WebRequest -UseBasicParsing -Method Head -Uri $url -TimeoutSec 30
        $size=[long]($head.Headers['Content-Length'] | Select-Object -First 1)
        # Google publishes no SHA256 in this manifest. A local receipt enables repeat reuse, not publisher verification.
        $receipt=$browserZip+'.sha256'; $digest=$null
        if ((Test-Path -LiteralPath $receipt) -and (Test-Path -LiteralPath $browserZip)) { $digest=(Get-Content -LiteralPath $receipt -Raw).Trim() }
        Download-File @($url) $browserZip $size $digest
        $googleHashes=[string]$head.Headers['x-goog-hash']
        if($googleHashes -match 'md5=([A-Za-z0-9+/=]+)') {
            $expectedMd5=$Matches[1]; $hex=(Get-FileHash -LiteralPath $browserZip -Algorithm MD5).Hash
            $bytes=New-Object byte[] 16
            for($i=0;$i -lt 16;$i++) {$bytes[$i]=[Convert]::ToByte($hex.Substring($i*2,2),16)}
            if([Convert]::ToBase64String($bytes) -ne $expectedMd5) { throw 'The browser ZIP does not match Google storage metadata. No browser files were installed.' }
            Write-Log 'Browser ZIP matches the MD5 published by Google storage.'
        }
        Set-Content -LiteralPath $receipt -Value ([KhuxSetup.Downloader]::Hash($browserZip)) -NoNewline
        Expand-Preserved $browserZip (Join-Path $root 'Browser') 'chrome-win64'
    }
    if (-not (Test-Path -LiteralPath $browser)) { throw 'Chrome extraction did not finish.' }
    & icacls.exe (Join-Path $root 'Browser') /grant '*S-1-15-2-1:(OI)(CI)(RX)' '*S-1-15-2-2:(OI)(CI)(RX)' /T /Q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure browser read access.' }
    $profile=Join-Path $root 'GameProfile'
    $arguments='--user-data-dir="'+$profile+'" --no-first-run --no-default-browser-check "'+$index+'"'
    $shortcutPath=Ensure-Shortcut $browser $arguments $root $DesktopPath
    $guidePath=Join-Path $root 'FIRST RUN.txt'
    if (-not (Test-Path -LiteralPath $guidePath)) {
        Set-Content -LiteralPath $guidePath -Encoding UTF8 -Value @"
KINGDOM HEARTS UX Theater + Dark Road
Open the desktop shortcut. In the game, choose the game folder:
$content
Wait for the first browser import to finish. Later, use the same shortcut.
Keep $profile intact: it holds your imported content and saves.
Close the game before backing up. Do not clear browser site data.
Source: https://archive.org/details/khux-5.0.1-ww-web
This installer preserves the existing archived browser edition without gameplay changes.
"@
    }
    Show-Status "Setup complete. Your shortcut is ready.`r`nOn first run, choose the Content folder in the game.`r`nSee FIRST RUN.txt for the folder path." 100
    if($script:form) {$button.Enabled=$false; $button.Text='Complete'}
    Write-Log 'Setup complete.'
    if (-not $NoLaunch) { Start-Process -FilePath $browser -ArgumentList $arguments; Start-Process notepad.exe -ArgumentList ('"'+$guidePath+'"') }
    if ($script:form -and $UiPreviewPath) {
        $bitmap=New-Object Drawing.Bitmap($script:form.Width,$script:form.Height)
        $script:form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$bitmap.Width,$bitmap.Height)))
        $bitmap.Save([IO.Path]::GetFullPath($UiPreviewPath)); $bitmap.Dispose()
    } elseif ($script:form) { [Windows.Forms.MessageBox]::Show($script:form,"Setup complete. Open the desktop shortcut and choose the Content folder on first run.`r`n$content",'Setup complete') | Out-Null }
} catch {
    Write-Log $_.Exception.ToString()
    $message=$_.Exception.Message+"`r`nExisting game files, profiles, saves, and partial downloads are preserved. Run setup again to resume.`r`nDetails: $script:logPath"
    if ($script:form) { [Windows.Forms.MessageBox]::Show($script:form,$message,'Setup stopped') | Out-Null } else { Write-Error $message -ErrorAction Continue }
    exit 1
} finally {
    if($lock) {$lock.Dispose()}
    $script:finished=$true
    if($script:form) {$script:form.Dispose()}
}
