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
