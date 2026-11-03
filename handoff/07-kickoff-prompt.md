# Kickoff prompt for the agent on the Plasma host

Paste the block below as the first message to the agent that will test the port in the KDE Plasma session.

```text
You are continuing the MacShell KWin port on a machine running KDE Plasma 6 Wayland. The code is on branch
`kwin-port` of this repository (github.com/OngYean/MacShell-KWin). It was written and statically checked on another
machine: the bridge compiles against Qt 6.12 and KWayland 6.8.2 headers, and CI builds the Nix packages and runs a
headless-KWin smoke test, but nothing has been run in a real Plasma session yet.

Read, in this order:
1. AGENTS.md: authoritative rules, including the Git and validation rules in §12.
2. handoff/05-kwin-port.md: what the branch implements, its capability matrix and known gaps.
3. handoff/06-kwin-testing-guide.md: the runbook you will follow with me.

Then:
- `git fetch && git switch kwin-port && git pull`, and confirm the latest CI run on the branch is green
  (Actions tab), noting what its kwin-smoke job reported.
- Work through the guide's "First 30 minutes", then sections 2 onwards, in order. Ask me before every step marked
  [ask]. Never use sudo, never edit Plasma/KWin config or my Nix config without asking, never disable plasmashell
  persistently, never run install.sh.
- Treat the bridge's normal output and QML logs as sensitive (window titles, menu labels): share only `--check`
  output, exit codes and QML warning lines.
- Fix what breaks in small separate commits (wip/fix per AGENTS.md §12; feat/fix only for behaviour verified here),
  keep the fake bridge (kwin-bridge/fake-bridge.py) and nix/kwin-smoke.sh working, and push to kwin-port.
- Keep the results table in section 17 of the guide up to date and finish by updating handoff/00-project-state.md
  and handoff/05-kwin-port.md with what was verified.
```
