# Optional programs as a choice in every way of installing (2026-11-17)

`AGENTS.md` remains the authority. This file covers one request the user sent on 2026-11-17 for branch `pending-test`.

**State: written and pushed to `pending-test` on 2026-11-17 as `wip` commits. Nothing has been evaluated by Nix, built by `makepkg` or run on Linux.**

| ID | Request (user's words, shortened) | Status |
| --- | --- | --- |
| F25 | For every packaging option, all optional dependencies (kdialog for selecting folders, cliphist for clipboard history) can be chosen by the user. Nix: an option to toggle these features. PKGBUILD: optional dependencies with a description of what they do. Manual script: ask the user whether they want these features. | written, untested |

## The features

A feature is a set of programs MacShell looks for when the feature is used and does without when they are missing. The list was made by searching `MacShell/` and `MacLock/` for the programs they start, and leaving out what only the Hyprland side uses (`grim`, `slurp`, `wf-recorder`, `brightnessctl`, `hyprctl`).

| Name | Programs | What it gives |
| --- | --- | --- |
| `pickers` | `kdialog` | The Choose… buttons in Settings (Dock folders, wallpaper and screenshot folders) and picture widgets |
| `clipboardHistory` | `cliphist`, `wl-clipboard` | Clipboard history in Spotlight; MacShell starts the `wl-paste --watch` watchers itself |
| `trashWatch` | `inotify-tools` | The Trash icon changes at once instead of within 3 s |
| `fileIcons` | `file` | File-type icons in a Dock folder's stack |
| `systemReport` | `fastfetch` | The system report behind About This Linux |
| `screenshots` | Spectacle | Screenshots and screen recording |
| `onlineLookups` | `curl`, `jq`, `python3` | Lyrics, stocks and location lookups (widgets, lock screen) |
| `wallpaperColors` | ImageMagick | Colours taken from the wallpaper |
| `videoGlass` | `ffmpeg` | A 720 px copy of a video wallpaper for the glass |
| `menuShortcuts` | `ydotool` and its `ydotoold` service | Shortcut items in the generic File and Edit menus |

Not features, because a package alone does not make them work: PowerDevil (brightness), NetworkManager (Wi-Fi), BlueZ (Bluetooth), power-profiles-daemon (power mode). They stay in the PKGBUILD's `optdepends` and the README names them.

## How each route offers the choice

- **Home Manager** (`nix/home-manager.nix`): `programs.macshell.features.<name>`, a boolean per feature, generated from one `features` attribute set (default, description, packages). On adds the packages to `home.packages`, which puts the programs on the session's `PATH`, where MacShell's wrapper already looks. `menuShortcuts` has no switch: `ydotoold` is a system service.
- **PKGBUILD:** `optdepends` rewritten so each entry says what it gives; `curl`, `jq`, `python`, `imagemagick`, `ffmpeg` and `power-profiles-daemon` are new entries.
- **`install.sh`** (KDE part): `kde_features` is the table; `kde_optional` runs after the install. On a terminal it asks about each feature whose programs are missing (Enter is no), collects the packages of the chosen ones for `pacman`, `dnf` or `apt-get` and runs one `sudo` install. `--features all|none|a,b` answers in advance, `--features-only` skips the build. Without a terminal and without `--features` nothing is installed. A failed package install is reported and does not fail the script: MacShell is already installed by then.
- **CMake by hand:** nothing to choose with; the README says to install the programs yourself.

## Decisions

- **A switch that is off installs nothing; it does not disable the feature.** A program that is on `PATH` for another reason still works. Hiding a feature whose program is present would need a setting inside MacShell, which was not asked for.
- **All Home Manager switches are off by default except `fileIcons`.** The module installed no optional program before, apart from `file`, which the package's wrapper carried. Off by default keeps a rebuild from adding packages nobody chose; `fileIcons` on keeps the stack's icons for existing users.
- **`file` left the package's wrapper** (`flake.nix`), so the choice is in one place. Cost: `nix run .#macshell` without the module shows generic icons in a Dock folder unless `file` is on `PATH`.
- **The script asks only about what is missing** and never removes a package. "Excluded" means not installed by the script.
- **The answer defaults to no,** because a yes runs `sudo`.
- **Package names per distribution** in `kde_features` are from memory, not checked against the repositories: `kde-spectacle` (Debian), `ffmpeg-free` and `ImageMagick` (Fedora), `python` (Arch). `cliphist` and `fastfetch` may be missing from older Fedora, Debian or Ubuntu releases; the script then says the package manager did not finish.
- **Home Manager collisions:** a feature's package can collide with another variant of the same program in the user's own `home.packages` (for example `ffmpeg-full` with `videoGlass`). Leave that switch off then.

## What was checked

- `sh nix/test-install.sh` passes on the macOS dev box (cmake from pip), with two new parts: the three lists name the same features (a scratch copy with one `optdepends` line removed, and one with a renamed Home Manager switch, both fail), and `install.sh --features-only` with stand-ins for `sudo` and `pacman` installs the chosen feature's packages only, installs nothing for `none` and refuses an unknown name.
- The questions were answered on a pseudo-terminal (`script`): yes installs, Enter and no do not.
- `bash -n` on `install.sh` and the PKGBUILD. `nix/home-manager.nix` and `flake.nix` parse with tree-sitter's Nix grammar (syntax only).
- **Not checked:** Nix evaluation of the module (no Nix here, and CI does not run: the account is locked); the CI step added for it (`features.clipboardHistory = true` must put `cliphist` and `wl-clipboard` in `home.packages`, `file` by default, no `kdialog`) has therefore never run. `makepkg`, `shellcheck`, and the script on any Linux distribution.

## Test

**Home Manager (NixOS):**

1. Rebuild without changing your configuration. This is the first time the new module is evaluated: if it fails, send the error. Expected: it builds, and `file` is still found (`command -v file`).
2. Add `programs.macshell.features.pickers = true;` and `features.clipboardHistory = true;`, rebuild, log out and in (or restart MacShell from a shell that has the new `PATH`). `command -v kdialog cliphist wl-paste` prints three paths.
3. Settings → Applications → Folders in Dock → Choose…: a KDE folder dialog opens. Copy some text twice, open Spotlight's clipboard button: both entries are listed.
4. Set `features.fileIcons = false;` and rebuild: unless `file` is installed some other way, a Dock folder's stack shows generic icons for files.

**Arch:**

5. `makepkg -si` in `packaging/arch`, then `pacman -Qi macshell-kwin-git`: "Optional Deps" lists each program with what it gives, and marks the installed ones.

**`install.sh` (any distribution, in a Plasma session):**

6. `./install.sh --features-only`: a line per feature; the ones whose programs are present say "already available", the others ask. Answer y to one and Enter to the rest: one `sudo` package install with that feature's packages only.
7. `./install.sh --features none`: installs MacShell and asks nothing. `./install.sh --features nope` stops with the list of names.
8. A package name your distribution does not have: the script says the package manager did not finish and still ends with "MacShell … is installed".
