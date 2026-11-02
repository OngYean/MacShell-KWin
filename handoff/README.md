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
- [`03-plasma-poc.md`](03-plasma-poc.md) — safe minimal top-panel/dock test plan for the user's future Plasma Wayland session.
- [`04-nix-and-install.md`](04-nix-and-install.md) — current Nix baseline and future KWin-aware deployment work.

## Current coordination state (2026-11-02)

- Repository: `MacShell-KWin`; current HEAD is `bcadc79` (`docs(agents): add Git commit and validation rules`). The source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` (`Update MacShell files`); it is historical, not current HEAD.
- Workspace source is an upstream-derived MacShell checkout, not yet a KWin port. README identifies `0-ss/MacShell` as upstream. No separate, verified KWin fork or external Nix/Home Manager repository is present here.
- Current runtime is Hyprland. The user plans to enable `services.desktopManager.plasma6.enable` in their host configuration themselves and will notify the project when they enter a standard Plasma 6 Wayland session. **Do not change host config, switch sessions, install packages or run installers.**
- Current flake work: `flake.nix`, `flake.lock` and `PACKAGING.md` were added. The lock pins unstable Nixpkgs at `0bb2eedc20e4739f29e8045034f2828ad7054f8f` (2026-11-01); that revision evaluates Quickshell `0.3.2`. `nix flake check path:. --no-build --all-systems` passed. No package build/run was performed.
- `install.sh` remains unchanged and Hyprland-specific. Do not treat it as a KWin installer.
- No KWin backend, Global Menu renderer, or KWin runtime test has been implemented. No files under `MacShell/` or `MacLock/` have been ported.

## Independent-work rules

- Each task brief states its permitted scope and expected output. Keep work within that scope; do not modify another lane's implementation or duplicate its investigation.
- Prefer source research and a written result until the user's Plasma-session signal arrives. A result must separate verified facts, inferences, version-dependent behavior and open questions.
- Do not mark mock menus as Global Menu support. Do not bind private or desktop-environment-only KWin protocols from an ordinary Quickshell process without a documented trust/access decision.
- Preserve KWin, Klassy/KDecoration3, plasmashell, native locking, notifications, tray ownership, KDE services and rollback paths. Never replace application decorations or run privileged configuration commands without explicit approval.
- For source edits, inspect existing code first, make minimal scoped changes, validate them, and state exactly what was and was not tested.
