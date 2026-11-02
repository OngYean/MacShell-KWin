# Global Menu renderer POC

This fixture renders the **actual active application's D-BusMenu tree** in a Quickshell panel. It is deliberately separate from `MacShell/` and does not replace Plasma's native Global Menu widget.

## Run

From the repository root, inside the current Plasma/KWin Wayland session:

```sh
nix develop --command qs --verbose --path ./poc/global-menu/shell.qml
```

The current POC source directory is untracked, so this `nix develop` invocation may fail when Nix excludes the helper's source path. The fixture was runtime-tested through a temporary `nix shell --impure --expr` invocation containing the locked Quickshell and `kwin-backend-probe` derivations. Re-test the conventional dev-shell command after the POC files are tracked.

Keep plasmashell and its Global Menu widget running for comparison. The fixture currently targets `eDP-1`, matching the accepted basic panel/dock POC. It exits with Quickshell; it does not change session configuration or app state.

The helper obtains the active window's AppMenu service/path through the same isolated, version-coupled Plasma Window Management diagnostic as `poc/kwin-backend-probe/`, then calls D-BusMenu `GetLayout`. `--menu-watch` polls the active window and full menu tree once per second and writes snapshots, including actual menu labels, only to Quickshell's local helper pipe. Never redirect or paste raw output from this mode into logs or reports.

The panel draws top-level items from the returned tree and shows nested popup levels. It sends D-BusMenu `opened`, `closed` and `clicked` events through a narrow JSON-lines stdin bridge. The helper accepts only event names and item IDs present in its latest active-window menu tree, and rechecks that the active window/address still matches before sending the D-Bus call. This event path is implemented but not yet runtime-verified. Keyboard navigation, shortcuts, dynamic property signal handling, icons and mnemonics are not implemented. The application label is derived from the active window's app ID, not Plasma's native task model. This remains an isolated POC, not a functional replacement for the native widget.

## Safety and support status

- Keep Plasma's native Global Menu widget available as the comparison and fallback.
- The active-window address currently comes from `org_kde_plasma_window_management`, which is a privileged, version-coupled desktop-environment protocol. Its use remains isolated to this diagnostic helper and must not be promoted into production without an explicit trust/version policy and supported fallback.
- The helper reads the D-BusMenu tree but does not print the service/path or menu labels to terminal output. In `--menu-watch`, menu labels necessarily travel through the local pipe to the renderer.
- Do not use the existing `--watch` raw window metadata output in logs.
- The helper's sanitized live-tree check on 2026-11-02 reported 8 root items, 132 total items and 96 non-empty labels for the active exported menu; labels were not printed. A bounded Quickshell run reached `Configuration Loaded` with no QML errors, but user visual acceptance of this renderer and runtime verification of menu events are still pending. Native Wayland KWrite is the first target; Xwayland and other app/toolkit combinations remain separate, untested cases.
