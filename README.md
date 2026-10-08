# KHUX Theater Tracker & Windows Game Setup

[Open the 332-entry Theater Tracker](https://qqclutchyqq.github.io/khux-theater-tracker/)

## Get the game on Windows

**[Download Windows Setup](https://qqclutchyqq.github.io/khux-theater-tracker/KHUX-Windows-Setup.zip)**

1. Download the ZIP, right-click it and choose **Extract All**.
2. Open the extracted folder and double-click **START SETUP.vbs** (START SETUP.cmd also works).
3. Let setup finish downloading and extracting about 2.5 GB. Allow 10 GB free.
4. The game and a first-run guide open. Click **Choose Files / Game folder**, select the **Content** folder shown in the guide, and confirm **Upload**. This imports files locally into the browser.
5. After that, use **KINGDOM HEARTS UX + Dark Road** on your desktop.

Requires 64-bit Windows 10/11, internet for setup, and PowerShell 5.1 or later. Setup installs under your own Local AppData folder, includes Google's official standalone Chrome, and creates a dedicated game profile. Administrator access is normally unnecessary. Initial content import is one manual step; setup does not bypass browser permission prompts.

**Dark Road is playable. Union χ is Theater Mode/avatar customization from the final offline 5.0.1 release, not restored live-service gameplay.**

Game files are downloaded directly from [the Internet Archive preservation release](https://archive.org/details/khux-5.0.1-ww-web), verified against pinned SHA256 checksums derived from files matching the Archive’s published SHA1 references, and kept in their original Content/v1 layout. This repository distributes the setup helper, not a copy of the game files. Downloads depend on Internet Archive and Google being available. The release includes modified level-stat bonuses, enemy-kill requirements, and title-screen version text.

Do not delete `GameProfile` or clear its browser data: that removes saved progress/imported content. Close the game before backing up its installation folder. Rerunning setup preserves GameProfile, existing game files, and the existing shortcut. Different existing game files cause setup to stop safely. The bundled Chrome does not auto-update; use it for this local game only.

## Optimized Windows installer 2.0.0 — October 8, 2026

The existing download URL now provides the optimized installer. It contains setup scripts, checksum metadata, instructions, and the existing editor guide; **no game HTML, OBB, video, image, game archive, or browser executable is bundled**.

Downloads prefer verified Internet Archive storage replicas and include resumable chunks, adaptive one/two/four connections, retry/backoff, SHA256 verification, cache reuse, and a progress window with Pause. Complete verified installations skip downloads and extraction, including when less than 10 GB remains free. Fresh downloads/extraction still require 10 GB free.

Testing covered a fresh install, real Archive interruption/resume, corrupt-cache recovery, fallback, extraction, shortcut preservation, and offline title-screen startup. All 222 files in an isolated imported browser profile were unchanged across an installer rerun. A measured near-full 2.08 GiB Content download plus combination/checksum took 7m09s, averaging 5.23 MB/s versus the original 149 KB/s sample (~35×); speeds vary by server and connection. Full gameplay/progressed-save round trips were not tested.

- [Checksums](https://qqclutchyqq.github.io/khux-theater-tracker/SHA256SUMS.txt)
- [Release details](https://qqclutchyqq.github.io/khux-theater-tracker/installer-release.html)
- [Original installer rollback](https://qqclutchyqq.github.io/khux-theater-tracker/KHUX-Windows-Setup-Legacy.zip)

The rollback ZIP is an exact copy of the public installer downloaded before this update. Close any old installer before running the new setup. Neither installer should be used to replace a modified game installation; keep the game profile and save data intact.

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
