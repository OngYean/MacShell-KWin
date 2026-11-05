# Kickoff prompt for the agent on the Plasma host

Paste the block below as the first message to the agent that will test the port in the KDE Plasma session. It was last updated on 2026-11-05, for branch `pending-test`.

```text
You are continuing the MacShell KWin port on a machine running KDE Plasma 6 Wayland (NixOS). The repository is
github.com/OngYean/MacShell-KWin. Test branch `pending-test`: the staging branch for everything not yet tested in
Plasma, before it goes into `main`. It holds kwin-plasma-fixes, fork-credits-readme, kwin-replace-wallpaper-splash
and kwin-magic-lamp, plus fixes committed straight to it. It was written on a macOS machine without Nix or Plasma.
CI builds the Nix packages and runs a headless-KWin smoke test, and passes, but none of the changes since `main`
have run in a real Plasma session.

Read, in this order:
1. AGENTS.md: the rules that govern everything, including §11 rule 15 (keep the README's changes list current) and
   the Git and validation rules in §12.
2. handoff/README.md, the newest "Update" section, then handoff/00-project-state.md, section "Current state".
3. The test plans, in the order you will run them:
   - handoff/08-plasma-fixes-tests.md: bar background, force blur, brightness, notifications without a Plasma tray,
     wallpaper sync, global menu icons;
   - handoff/09-fork-credits-readme.md: credits, the update check, the Apple logo, the README's install steps;
   - handoff/10-replace-wallpaper-splash-tests.md: the wallpaper and login splash without plasmashell;
   - handoff/12-replace-default-tests.md: replacing plasmashell as the default launch, and the Home Manager mode;
   - handoff/11-kwin-blur-tests.md: "Use KWin's blur";
   - handoff/13-magic-lamp-tests.md: Magic Lamp minimizes windows into their Dock icon;
   - handoff/14-sharp-bar-icons-tests.md: the menu bar's icons stay sharp at any UI and display scale.
4. handoff/06-kwin-testing-guide.md: the general runbook, ground rules and rollback, for reference.

Then:
- `git fetch && git switch pending-test && git pull`. Confirm the latest CI run on the branch is green.
- Work through the plans in that order. Ask me before every step that changes anything on the host. Never use sudo,
  never edit Plasma or KWin config or my Nix config without asking, never disable plasmashell persistently, and
  never run install.sh. `macshell-session stop` (from KRunner, Alt+Space) always brings plasmashell back.
- Treat the bridge's normal output and QML logs as sensitive (window titles, menu labels). Share only `--check`
  output, exit codes and QML warning lines.
- Fix what breaks in small separate commits on pending-test. Follow AGENTS.md §12: use wip until a behaviour is
  verified here, and feat or fix only once it is. Keep kwin-bridge/fake-bridge.py, nix/kwin-smoke.sh and
  nix/test-brightness.sh working. Update README.md's changes list for every user-visible change, and push to
  pending-test.
- Fill in the results in each plan. Finish by updating the "Current state" section of
  handoff/00-project-state.md, and handoff/05-kwin-port.md, with what was verified.
```
