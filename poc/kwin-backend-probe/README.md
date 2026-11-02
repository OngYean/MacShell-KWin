# KWin window-management probe and Global Menu bridge

This opt-in diagnostic checks KWin's `org_kde_plasma_window_management` global and bridges read-only state into a separate Quickshell test panel. The Wayland helper gathers window IDs, titles, app IDs, geometry, state, virtual-desktop IDs, and AppMenu service/path addresses; the Quickshell panel displays only aggregate count/focus/menu/workspace status. Window metadata stays in the local helper-to-Quickshell pipe and is not logged by the panel.

The protocol XML labels Plasma Window Management a privileged desktop-environment implementation detail and says regular clients must not use it. KWin 6.8.2 filters the global from sandboxed clients, while its server-side resource implementation permits the client behavior observed in this session. This remains a KDE/KWin-specific, version-coupled experiment—not a stable public Wayland backend or a cross-compositor API. Do not wire it into the main shell without an explicit trust/version policy and a fallback.

The helper also reads KWin's `org.kde.KWin.VirtualDesktopManager` D-Bus properties for current workspace ID/count. It does not switch workspaces or perform KWin window actions. The ordinary `--watch` snapshot marks activation unimplemented, capture unsupported, and Global Menu address-only; the separate `--menu-watch` POC mode retrieves the D-BusMenu tree and sends validated menu events only. It uses `QGuiApplication`, because KWayland may deserialize window-icon data, and drains its event loop briefly before clean one-shot teardown so queued icon decoding finishes while the GUI application is alive.

## Run the QML bridge fixture

From the repository root (when the POC source paths are in the Git worktree source):

```sh
nix develop --command qs --verbose --path ./poc/kwin-backend-probe/shell.qml
```

While the local POC directory is untracked, `nix develop` may fail because Nix excludes untracked source paths. The direct `nix build path:.#kwin-backend-probe` and `nix run` checks work; a temporary `nix shell --impure --expr` invocation with the locked Quickshell and probe derivations was used for the renderer runtime test. Re-run the conventional `nix develop` command once the sources are tracked.

It starts a persistent local helper with a one-second read-only refresh and displays a status panel on `eDP-1`. Keep plasmashell running; the process exits when Quickshell exits. No autostart, settings, window state, or workspace state is changed. For a bounded visual check:

```sh
timeout --signal=INT --kill-after=2s 30s nix develop --command qs --verbose --path ./poc/kwin-backend-probe/shell.qml
```

The helper's `--watch` mode emits newline-delimited JSON containing window metadata. Run it only as the local QML bridge or redirect/filter its output carefully; do not paste raw output into logs or reports. The ordinary `nix run .#kwin-backend-probe` mode remains a summary-only diagnostic. To perform one read-only D-BusMenu layout request against the current active window's registered address, run `nix run .#kwin-backend-probe -- --menu-check`; it reports the result and root-item count, but never menu labels or the service/path. `--menu-watch` is only for `poc/global-menu/shell.qml`: it polls `GetLayout` each second, streams actual menu labels to that local process, and accepts validated `opened`/`closed`/`clicked` event commands on stdin. Never print, redirect or paste its raw output; do not use it outside the isolated POC.

## Verified so far

On 2026-11-02, the helper built and ran in the Plasma/KWin `6.8.2` session while plasmashell was running. Its summary reported protocol v21, six windows, active-window presence, workspace-read availability, and KWin's AppMenu registration global. With KWrite confirmed active (`appId=org.kde.kwrite`), the address initially appeared absent but later settled to present; `--menu-check` retrieved the read-only D-BusMenu `GetLayout` reply and reported 8 root items. The active KWrite process maps Qt's `libqwayland.so` and not `libqxcb.so`, identifying this as native Wayland; Xwayland remains untested. The user confirms Plasma's native Global Menu widget displays KWrite's actual menu items. A separate sanitized `--menu-watch` check reported 8 root items, 132 total items and 96 non-empty labels without printing labels. The new Quickshell fixture at `poc/global-menu/` reached `Configuration Loaded` in bounded runs; its most recent runtime reported no QML errors or deprecated `PopupWindow` property warnings. The user has not yet confirmed this renderer's appearance or submenu interaction. The D-BusMenu event path builds and is wired, but event delivery/activation remains unverified. Tests are fixture-only; Xwayland, other toolkits, window activation requests, workspace switching, output hotplug, capture and long-duration behavior remain open.
