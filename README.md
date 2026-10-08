# KHUX Theater Tracker & Windows Game Setup

[Open the 332-entry Theater Tracker](https://qqclutchyqq.github.io/khux-theater-tracker/)

## Download

**[Download the latest stable Windows installer](https://github.com/qqCLUTCHYqq/khux-theater-tracker/releases/latest/download/KHUX-Windows-Setup.zip)**

[Release notes and all downloads](https://github.com/qqCLUTCHYqq/khux-theater-tracker/releases/latest) ·
[2.0.0 rollback](https://github.com/qqCLUTCHYqq/khux-theater-tracker/releases/download/v2.0.1/KHUX-Windows-Setup-2.0.0.zip)

Installer SHA256: `1179a56f31522084eba6df84d5547cb840bae4cc708bb09c535639df47f06e20`.
Extract the ZIP and run **START SETUP.cmd**. The ZIP includes only the setup helper and
permitted support files; game files and browser binaries are downloaded separately.
After an interruption, run the same launcher again to resume. Existing saves are preserved.

1. Download the ZIP, right-click it and choose **Extract All**.
2. Open the extracted folder and double-click **START SETUP.cmd**. Support files are grouped under App.
3. Let setup finish downloading and extracting about 2.5 GB. Allow 10 GB free.
4. Click **Launch Game** in the completion screen and **Copy Content folder path**. In the game, click **Choose Files / Game folder**, select the **Content** folder shown by setup, and confirm **Upload**. This imports files locally into the browser.
5. After that, use **KINGDOM HEARTS UX + Dark Road** on your desktop.

Requires 64-bit Windows 10/11, internet for setup, and PowerShell 5.1 or later. Setup installs under your own Local AppData folder, includes Google's official standalone Chrome, and creates a dedicated game profile. Administrator access is normally unnecessary. Initial content import is one manual step; setup does not bypass browser permission prompts.

**Dark Road is playable. Union χ is Theater Mode/avatar customization from the final offline 5.0.1 release, not restored live-service gameplay.**

Game files are downloaded directly from [the Internet Archive preservation release](https://archive.org/details/khux-5.0.1-ww-web), verified against pinned SHA256 checksums derived from files matching the Archive’s published SHA1 references, and kept in their original Content/v1 layout. This repository distributes the setup helper, not a copy of the game files. Downloads depend on Internet Archive and Google being available. The release includes modified level-stat bonuses, enemy-kill requirements, and title-screen version text.

Do not delete `GameProfile` or clear its browser data: that removes saved progress/imported content. Close the game before backing up its installation folder. Rerunning setup preserves GameProfile, existing game files, and the existing shortcut. Different existing game files cause setup to stop safely. The bundled Chrome does not auto-update; use it for this local game only.

## Windows installer 2.0.1 â€” October 8, 2026

One setup entry point, grouped support files, a clearer four-step window, Launch Game,
Copy Content folder path and whole-profile save backup/restore instructions. Logs
and configuration live under Setup. Existing game/profile/download paths and shortcuts
remain unchanged. The optimized downloader is unchanged: verified Archive replicas,
resumable chunks, adaptive 1/2/4 connections, retry/backoff, checksum checks and fallback.
First import still requires one guided folder selection. Later launches use cached data.

Fresh installation/extraction, existing installation detection, real Archive resume,
corruption/fallback fixtures, offline import/restart, Union chi menu and Dark Road startup,
full-profile backup/restore and completion controls passed isolated testing. All 222 files
of the existing imported profile were unchanged across setup rerun. No real saves were
touched; full gameplay was not tested. The ZIP contains only six installer/support files.

- [Checksums](SHA256SUMS.txt)
- [Release details and test limits](installer-release.html)
- [2.0.0 rollback](https://github.com/qqCLUTCHYqq/khux-theater-tracker/releases/download/v2.0.1/KHUX-Windows-Setup-2.0.0.zip)
- [Original legacy rollback](KHUX-Windows-Setup-Legacy.zip)

Rollback replaces the setup helper only. Keep the installed game and GameProfile intact.

## Tracker

All 332 entries from the supplied tracker are preserved. Checkboxes, Watch Next, search, and Remaining Only work in the browser. Checklist progress is saved separately on each device/browser; it is not synced. On iPhone, open the tracker in Safari and choose Share → Add to Home Screen.


## Game speed and save editor

[Read the complete editor guide](https://qqclutchyqq.github.io/khux-theater-tracker/editor-guide.html). It covers every field, Set, keep, Unlock, Refresh, save writing, backups, legacy currencies, and unmapped internal flags. An offline copy named editor-guide.html is included in the setup ZIP.
## 🌙 Join Traverse Town

Need setup help, found a bug, have a suggestion, or just want to follow Cross Road development?

**[Join the Traverse Town Discord](https://discord.gg/jHWEkRdjJb)**

Traverse Town is the community home for Cross Road and our future KINGDOM HEARTS projects.

Come by for:

- 🛠️ Setup help
- 🐛 Bug reports and tracking
- 💡 Suggestions and feature ideas
- 📢 Cross Road updates
- 🗝️ KINGDOM HEARTS discussion
- 🔧 Future projects and development

## Disclaimer

Cross Road is an unofficial fan/community preservation project and is not affiliated with or endorsed by Square Enix or Disney.
