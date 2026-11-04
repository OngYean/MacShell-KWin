# Kickoff prompt for the agent on the Plasma host

Paste the block below as the first message to the agent that will test the port in the KDE Plasma session. It was last updated on 2026-11-04, for branch `fork-credits-readme`.

```text
You are continuing the MacShell KWin port on a machine running KDE Plasma 6 Wayland (NixOS). The repository is
github.com/OngYean/MacShell-KWin. Test branch `fork-credits-readme`: it is based on `kwin-plasma-fixes`, which is
based on `main`, so it carries all the current work. It was written on a macOS machine without Nix or Plasma. CI
builds the Nix packages and runs a headless-KWin smoke test, but none of the changes since `main` have run in a real
Plasma session.

Read, in this order:
1. AGENTS.md: the rules that govern everything, including §11 rule 15 (keep the README's changes list current) and
   the Git and validation rules in §12.
2. handoff/00-project-state.md, section "Current state".
3. handoff/08-plasma-fixes-tests.md: six fixes to test (bar background, force blur, brightness, notifications
   without a Plasma tray, wallpaper sync, global menu icons).
4. handoff/09-fork-credits-readme.md: credits, the update check, the Apple logo, and the README's install steps.
5. handoff/06-kwin-testing-guide.md: the general runbook, ground rules and rollback, for reference.

Then:
- `git fetch && git switch fork-credits-readme && git pull`. Confirm the latest CI run on the branch is green.
- Work through 08, then 09, in order. Ask me before every step that changes anything on the host. Never use sudo,
  never edit Plasma or KWin config or my Nix config without asking, never disable plasmashell persistently, and
  never run install.sh.
- Treat the bridge's normal output and QML logs as sensitive (window titles, menu labels). Share only `--check`
  output, exit codes and QML warning lines.
- Fix what breaks in small separate commits. Follow AGENTS.md §12: use wip until a behaviour is verified here, and
  feat or fix only once it is. Keep kwin-bridge/fake-bridge.py, nix/kwin-smoke.sh and nix/test-brightness.sh
  working. Update README.md's changes list for every user-visible change, and push to fork-credits-readme.
- Fill in the results tables in 08 and 09. Finish by updating the "Current state" section of
  handoff/00-project-state.md, and handoff/05-kwin-port.md, with what was verified.
```
