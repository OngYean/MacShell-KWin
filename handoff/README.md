# Agent handoff index

These handoffs let an agent start from the repository without access to the original conversation. Each brief is self-contained: an agent may receive just its assigned file and still have the project goal, constraints, current state and task.

## Start here

1. Read the repository's `AGENTS.md`. It is the project authority for goals, milestones, acceptance criteria and safety rules. It is user-provided and tracked; **do not overwrite, move or delete it**.
2. Read exactly one task brief below. Do not assume another agent's findings or session context.
3. Verify the current repository state and re-check any upstream `master` references against the target release before relying on them.

## Task briefs

- [`00-project-state.md`](00-project-state.md) — self-contained baseline and milestone status.
- [`01-global-menu.md`](01-global-menu.md) — KDE AppMenu/D-BusMenu research and proof-of-concept plan.
- [`02-kwin-backend.md`](02-kwin-backend.md) — window, workspace, output and capture backend research.
- [`03-plasma-poc.md`](03-plasma-poc.md) — safe minimal top-panel/dock test plan and current Plasma session results.
- [`04-nix-and-install.md`](04-nix-and-install.md) — current Nix baseline and future KWin-aware deployment work.
- [`05-kwin-port.md`](05-kwin-port.md) — what the `kwin-port` branch implements (compositor facade, KWin bridge, global menu, Nix), decisions and known gaps.
- [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) — **start here to test the port**: step-by-step runbook with approval gates and the acceptance-criteria results table.
- [`07-kickoff-prompt.md`](07-kickoff-prompt.md) — ready-to-paste first message for the agent on the Plasma host.
- [`08-plasma-fixes-tests.md`](08-plasma-fixes-tests.md) — what to test for the six fixes on branch `kwin-plasma-fixes` (bar background, force blur, brightness, notifications, wallpaper sync, menu icons).
- [`09-fork-credits-readme.md`](09-fork-credits-readme.md) — branch `fork-credits-readme`: licence and credits, the Plasma-focused README, the update check, the branch layout and open licensing items.
- [`10-replace-wallpaper-splash-tests.md`](10-replace-wallpaper-splash-tests.md) — branch `kwin-replace-wallpaper-splash` (from `fork-credits-readme`): MacShell draws the wallpaper and ends the login splash when `plasmashell` isn't running. The first step towards dropping `plasmashell`.
- [`11-kwin-blur-tests.md`](11-kwin-blur-tests.md) — the "Use KWin's blur" option: every glass surface becomes a see-through tint with KWin's blur behind it. Design decisions and test plan.
- [`12-replace-default-tests.md`](12-replace-default-tests.md) — replacing `plasmashell` is the default launch (`macshell-session start`, Home Manager `mode = "replace"`), running side by side is `coexist`. How login skips `plasmashell`, the fallback, and the test plan.
- [`13-magic-lamp-tests.md`](13-magic-lamp-tests.md) — branch `kwin-magic-lamp`: KWin's Magic Lamp minimizes windows into their Dock icon instead of towards the pointer (bridge anchor surfaces + `set_minimized_geometry`). How it works and the test plan.
- [`14-sharp-bar-icons-tests.md`](14-sharp-bar-icons-tests.md) — on `pending-test`: the menu bar's icons stay sharp at any UI scale, bar height and display scale. Cause, fix and test plan.

## Update (2026-11-05, branches `kwin-magic-lamp` and `pending-test`)

Branches: `main` (`d53665e`) ← `kwin-plasma-fixes` ← `fork-credits-readme` ← `kwin-replace-wallpaper-splash` ← `kwin-magic-lamp`. All are in a straight line. `pending-test` is the staging branch for what still needs testing in Plasma before it goes into `main`. It holds every branch above, merged.

`kwin-magic-lamp` adds minimizing into the Dock (test plan: [`13`](13-magic-lamp-tests.md)). Bridge 0.2.0 builds layer-shell client code with `wayland-scanner` (new build inputs: `wayland-scanner`, `wlr-protocols`, `wayland-protocols`). The smoke test checks that KWin reports the registered rectangle as KWrite's `iconGeometry`. None of it has run in Plasma.

Committed straight to `pending-test`, on top of `kwin-magic-lamp`, so it is in no feature branch: the menu bar's icons stay sharp at any UI scale (test plan: [`14`](14-sharp-bar-icons-tests.md)). They were Canvas bitmaps stretched by the bar's `scale:` transforms, and Qt's Canvas didn't repaint on display-scale changes. Not run in Plasma or CI.

CI on `pending-test` passes at `3abdc32` (run `41991523455`). The Home Manager check had failed since `904342a`, on every branch, because Home Manager's `master` now stores `ExecStart` as a list. The check now takes both forms (`3abdc32`), and reports nix's own error in an annotation (`6917f87`). `kwin-magic-lamp` lacks both fixes, so its CI stays red. What the run shows:
- the bridge builds and links with the generated layer-shell code;
- against headless KWin 6.8.2, `--check` reports `icon_anchors=1`, and **KWin reports the rectangle the bridge registered as KWrite's `iconGeometry`**;
- the real bridge's messages, `iconAnchors` included, match the protocol;
- MacShell loads with the real and the fake bridge, and its only QML diagnostic is the old `Cannot open: file:///home/runner/.face`, so neither the Dock targets nor the new `Glyph` produce warnings;
- the Home Manager module evaluates with `mode=replace`, the drop-in and the fallback.

The animation and the icons' sharpness can only be judged in Plasma.

On the Plasma host, test from `pending-test`, in this order: [`08`](08-plasma-fixes-tests.md), [`09`](09-fork-credits-readme.md), [`10`](10-replace-wallpaper-splash-tests.md), [`12`](12-replace-default-tests.md), [`11`](11-kwin-blur-tests.md), [`13`](13-magic-lamp-tests.md), [`14`](14-sharp-bar-icons-tests.md). Start the agent there with [`07-kickoff-prompt.md`](07-kickoff-prompt.md), and commit fixes found in Plasma to `pending-test`.

## Update (2026-11-05, branch `kwin-replace-wallpaper-splash`)

Branches: `main` (`d53665e`) ← `kwin-plasma-fixes` (`701c526`) ← `fork-credits-readme` (`2644f5c`) ← `kwin-replace-wallpaper-splash`. The new branch is the newest and contains everything. Nothing has been merged into `main` since.

On 2026-11-05 the user decided that MacShell should run **without `plasmashell` by default**, for two reasons:
- MacShell's desktop layer takes the clicks meant for Plasma's desktop icons, so the two desktops can't share the screen.
- MacShell already covers most of the Plasma tray.

The branch adds three features towards that, all written on macOS without Nix, Quickshell or Plasma. **None has run in Plasma.**

1. **Wallpaper and login splash without `plasmashell`.** `MacShell/Wallpaper.qml` draws the wallpaper and sends KSplash's last stage. Test plan: [`10`](10-replace-wallpaper-splash-tests.md).
2. **Settings → Appearance → "Use KWin's blur".** Every glass surface becomes a see-through tint, and KWin blurs behind it (`GlassBlur.qml`, `BlurCollector.qml`). Test plan: [`11`](11-kwin-blur-tests.md).
3. **Replace is the default launch.**
   - `macshell-session start` replaces `plasmashell`, `coexist` runs MacShell side by side, and `stop` brings `plasmashell` back.
   - The Home Manager option `mode` defaults to `"replace"`. With `autostart` it skips `plasmashell` at login through a drop-in condition (never a mask), and `macshell-fallback.service` starts it again if MacShell keeps failing.
   - Test plan: [`12`](12-replace-default-tests.md).

Validation so far:
- `sh nix/test-macshell-session.sh` passes on macOS `sh` and `dash`.
- `git diff --check` is clean, and brace balance is unchanged in every edited QML file.
- qmllint, ShellCheck, Nix evaluation and the build were **not** run locally. The branch was added to the CI triggers so CI runs them on push. Its result: `https://api.github.com/repos/OngYean/MacShell-KWin/actions/runs?branch=kwin-replace-wallpaper-splash`.

On the Plasma host, test in this order: [`08`](08-plasma-fixes-tests.md) (still pending), [`10`](10-replace-wallpaper-splash-tests.md), [`12`](12-replace-default-tests.md), [`11`](11-kwin-blur-tests.md). What is still missing without `plasmashell` is listed in [`00-project-state.md`](00-project-state.md#current-state-2026-11-05).

## Update (2026-11-04, branch `fork-credits-readme`)

Branches: `main` (`d53665e`, with `kwin-port` merged) ← `kwin-plasma-fixes` (`701c526`) ← `fork-credits-readme` (`e4ac899`). All are pushed, and nothing has been merged into `main` since. `fork-credits-readme` is the newest branch and contains everything:

- the six untested Plasma fixes ([`08`](08-plasma-fixes-tests.md));
- the fork's licence and credits;
- the Plasma-focused `README.md`, whose list of changes from the original is now required by `AGENTS.md` §11 rule 15;
- the Software Update check pointing at `OngYean/MacShell-KWin`;
- the Apple logo trademark notice;
- the removal of leftover upstream files.

CI passes on `e4ac899`. None of it has run in Plasma. On the Plasma host, test from `fork-credits-readme` using [`08`](08-plasma-fixes-tests.md), then [`09`](09-fork-credits-readme.md).

## Update (2026-11-04, branch `kwin-plasma-fixes`)

The user reports the AppMenu export problem is fixed in their Plasma session and listed six remaining bugs. Branch `kwin-plasma-fixes` (from `main`, pushed to `origin`) has a `wip` fix for each one, written without Plasma. Test them with [`08-plasma-fixes-tests.md`](08-plasma-fixes-tests.md).

## Current state (2026-11-03, branch `kwin-port`)

The `kwin-port` branch (pushed to `origin`) implements Milestones 3–6 as `wip` commits. CI builds it and smoke-tests it against a headless KWin; it has not run in a real Plasma session. It adds the compositor facade (`MacShell/backends/compositor/`), the event-driven `macshell-kwin-bridge`, the real global-menu renderer in `MacBar.qml`, KDE session/service integration, and the Nix packaging (`macshell`, `macshell-kwin-bridge`, `macshell-session`, `homeManagerModules.macshell`). The next agent tests it in the Plasma session with [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md), starting from [`07-kickoff-prompt.md`](07-kickoff-prompt.md). The section below is the state before that branch.

## Coordination state before `kwin-port` (2026-11-02)

- Repository: `MacShell-KWin`; current committed HEAD is `f9037d5` (`docs(handoff): refresh repository state references`). The source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` (`Update MacShell files`); it is historical. Current POC and session-status edits are uncommitted.
- Workspace source is an upstream-derived MacShell checkout, not yet a KWin port. README identifies `0-ss/MacShell` as upstream. No separate, verified KWin fork or external Nix/Home Manager repository is present here.
- The user is now in a verified Plasma 6 Wayland session: KWin and plasmashell `6.8.2`, Qt `6.12.0`; `XDG_SESSION_TYPE=wayland`, `XDG_CURRENT_DESKTOP=KDE`. Do not change host config, switch sessions, install packages or run installers.
- The lock pins unstable Nixpkgs at `0bb2eedc20e4739f29e8045034f2828ad7054f8f` (2026-11-01), evaluating Quickshell `0.3.2` and KWayland `6.8.2`. The existing Hyprland shell was not built. On 2026-11-02, the diagnostic `kwin-backend-probe` built and ran in-session: KWin advertised Plasma Window Management v21 and AppMenu. With native-Wayland KWrite active (`org.kde.kwrite`), its AppMenu address appeared and the read-only `GetLayout` check retrieved 8 root items. A sanitized tree check counted 8 root / 132 total / 96 labeled items without printing menu text. The user confirms Plasma's native Global Menu widget displays KWrite's actual items. The isolated Quickshell renderer at `poc/global-menu/` loaded in bounded runs; its user visual verification and D-BusMenu Event/leaf activation tests remain pending. The active KWrite process maps Qt's `libqwayland.so`, not `libqxcb.so`; Xwayland remains untested. The user visually confirmed the separate basic panel/dock fixture on `eDP-1`, including disappearance on exit and no work-area shift.
- `install.sh` remains unchanged and Hyprland-specific. Do not treat it as a KWin installer.
- No production KWin backend or Global Menu renderer exists; no files under `MacShell/` or `MacLock/` have been ported. An isolated real-data Global Menu rendering POC exists at `poc/global-menu/`, but remains unverified visually and for Event/activation behavior. The basic layer-shell POC has user visual acceptance. Klassy remains unverified because KWin currently reports Breeze (`org.kde.breeze`). The C++ helper's Plasma Window Management access remains privileged, private/KWin-specific and version-coupled.

## Independent-work rules

- Each task brief states its permitted scope and expected output. Keep work within that scope; do not modify another lane's implementation or duplicate its investigation.
- Use the active Plasma session for reversible, manual tests. Do not change host configuration or persistent session settings. Separate verified facts, inferences, version-dependent behavior and open questions.
- Do not mark mock menus as Global Menu support. Plasma Window Management remains a privileged, desktop-only protocol despite the read-only diagnostic; do not wire it into ordinary Quickshell until the trust/access decision, version guards, and fallback are explicitly reviewed.
- Preserve KWin, Klassy/KDecoration3, plasmashell, native locking, notifications, tray ownership, KDE services and rollback paths. Never replace application decorations or run privileged configuration commands without explicit approval.
- For source edits, inspect existing code first, make minimal scoped changes, validate them, and state exactly what was and was not tested.
