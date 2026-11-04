# Branch `fork-credits-readme`: credits, licensing and README

`AGENTS.md` remains the authority. This brief covers branch `fork-credits-readme`, written on macOS without Nix, Quickshell or Plasma on 2026-11-04. The branch starts from `kwin-plasma-fixes` (`701c526`), so it also carries the six untested Plasma fixes from [`08-plasma-fixes-tests.md`](08-plasma-fixes-tests.md).

## Branch layout

```text
main d53665e  ←  kwin-plasma-fixes 701c526  ←  fork-credits-readme e4ac899
```

- `kwin-port` (`189cd3e`) is already merged into `main`; `main` is 4 commits ahead of it.
- All four branches are pushed to `origin` and match it.
- Merging `fork-credits-readme` alone brings in `kwin-plasma-fixes` too. Nothing has been merged yet.
- CI only runs on pushes to the branches listed in `.github/workflows/kwin-port.yml` (`[kwin-port, kwin-plasma-fixes, fork-credits-readme]`; `main` isn't listed) and on pull requests. Update that list when the branches are merged.

## What the branch changes

| Commit | Change | Validation |
| --- | --- | --- |
| `a7b9966` | `LICENSE`: two MIT copyright lines. One credits Rickky, with a link to the original `0-ss/MacShell`; the other credits OngYean for the KDE Plasma port. | text only |
| `fd92386` | Adds the Open Runde licence notice (OFL-1.1, Laurids Kern) with upstream's unchanged licence text in the three `OFL.txt` copies (`MacShell/assets/fonts`, `MacLock/fonts`, `MacInstaller/assets/fonts`). The gemoji MIT notice is at the top of `MacShell/EmojiData.js`. | text only; `EmojiData.js` still starts with `.pragma library` after the comments |
| `18ef9aa` | Every Nix package installs `LICENSE` to `share/licenses/<pname>/`. The shell packages declare `meta.license = [ mit ofl ]`; the bridge and the probe declare `mit`. `homepage` points to this fork. | CI build |
| `f9eda02` | CI also runs on pushes to this branch. | CI |
| `95b56f7` | `AGENTS.md` §11 rule 15: `README.md` must list what was added, changed and removed compared to `0-ss/MacShell` `51db0ba`. The list must say whether each change was tested in Plasma, and every user-visible change updates it. | text only |
| `1fdb3ff` | `README.md` rewritten around KDE Plasma installation. It sends Hyprland users to `0-ss/MacShell` and adds the changes list, the Home Manager options, `macshell-session`, troubleshooting, known issues and credits. | the install steps have not been followed on a real machine |
| `4e11f04` | Settings → Software Update checks `OngYean/MacShell-KWin` instead of the original (`MacShell/assets/check-update.sh` default `REPO`, `updateUrl` in `MacBar.qml`). It compares against `MacShell/VERSION` on `main`, or the latest GitHub release if one exists. | The script, run on macOS, printed `{"status":"uptodate","latest":"0.5.1","current":"0.5.1","url":"https://github.com/OngYean/MacShell-KWin"}`. The Settings UI was not run. |
| `3d46ca3` | Both `MacShell/apple-logo-*.svg` files start with a comment saying the logo is Apple's trademark and artwork, isn't covered by the MIT licence, and that this project isn't affiliated with Apple Inc. The README's trademark paragraph says the same. | both files still parse as XML with an `svg` root |
| `c1df10a` | Settings → About → Credits lists OngYean as the porter. The avatar `MacShell/assets/credits/OngYean.png` is GitHub's default pattern avatar; replace it if the user sets a real one. | **not run.** The commit is typed `feat`, but under §12 it should have been `wip`. It wasn't amended, because amending needs the user's request. |
| `e4ac899` | Removes files left over from upstream: `MacLock/__pycache__/*.pyc`, `hypr-macshell/scripts.zip` (identical to `hypr-macshell/scripts/`) and four `.gitkeep` files in folders that have content. A root `.gitignore` keeps Python caches out. | Nothing referenced them. |

CI [run 41759151297](https://github.com/OngYean/MacShell-KWin/actions/runs/41759151297) on `e4ac899`: `build` and `kwin-smoke` succeeded. CI never opens the Settings window and has no network check, so it covers none of the UI changes above.

## What to test in Plasma

Follow the setup in [`08-plasma-fixes-tests.md`](08-plasma-fixes-tests.md), but on this branch: `git switch fork-credits-readme`. All of the following are read-only for the host.

1. **Credits:** Settings → About → Credits shows three entries (Rickky, vSuol, OngYean). OngYean's avatar loads, and the `@OngYean` link opens `github.com/OngYean`. The console shows no QML warning mentioning `credits` or `OngYean.png`.
2. **Update check** (needs network): Settings → Software Update reports MacShell as up to date at 0.5.1, and its button opens `github.com/OngYean/MacShell-KWin`.
3. **Apple logo:** set the menu bar logo to the Apple logo in Settings. It must still render, now that the SVGs start with a comment. Then set it back.
4. **README install steps:** read the "NixOS with Home Manager" section and check it against `nix/home-manager.nix` and `flake.nix`. The input name, the `programs.macshell` option names and the `nix flake update macshell` command must all match. Don't apply anything to the user's Nix configuration without their approval. Report wrong instructions as README fixes.
5. **Regressions:** MacShell starts with no new QML warnings, apart from the known missing `~/.face`.

| Check | Result (`pass` / `fail` / `partial`) | Evidence |
| --- | --- | --- |
| 1. Credits | | |
| 2. Update check | | |
| 3. Apple logo | | |
| 4. README install steps | | |
| 5. Regressions | | |

## Open items (not done; the user decides)

- **Music icons:** nobody knows where `MacShell/assets/music-app.svg`, `music-note.svg` and `idle-music-note.png` come from, and they use Apple Music–like artwork. Ask the upstream authors or replace them. Neither has been done.
- **Upstream links in Hyprland-only paths:** `install.sh`, `MacShell/macshell-update`, `MacInstaller/shell.qml` (`projectUrl`) and the "Hyprland Keybinds" help link in `MacBar.qml` still point at `0-ss/MacShell`. This is deliberate: they install or describe the Hyprland version, which the README sends to upstream. Change them only if this fork is to support Hyprland installs.
- **`PACKAGING.md` is stale:** it still says the shell depends on Hyprland and calls `kwin-port` untested. `README.md` is now the install guide. Either update `PACKAGING.md` or reduce it to developer notes.
- **README changes list (rule 15):** every later fix on these branches must update it in the same branch, including the Plasma test result once the rows in `08` and above are filled in.
