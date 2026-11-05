# Test plan: "Use KWin's blur"

`AGENTS.md` remains the authority, and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) has the general runbook and rollback. This covers the option **Settings → Appearance → Use KWin's blur**, requested by the user on 2026-11-05. With it on, every glass surface becomes a see-through tint, and KWin blurs what's behind each one, instead of MacShell's own Liquid Glass pipeline. It was written on macOS without Nix, Quickshell or Plasma. **Nothing has run in Plasma, and the QML has not been linted** (no `qmllint` on the development machine).

## How it works (decisions)

- **Protocol.** Each surface's outline goes to KWin as the window's blur region. Quickshell's `BackgroundEffect.blurRegion` sends it over `ext-background-effect-v1`, which is what the bar-strip fill already used. This is a public Wayland protocol, not a KWin script or private interface.
- **One region per window.** A window has a single blur region.
  - `MacShell/BlurCollector.qml` sits directly in each window that holds glass, and assigns the union of its parts to the window:
    - bar windows: the bar, the switcher, the wallpaper picker, the volume/brightness pop-up, Spotlight;
    - the Dock;
    - the desktop;
    - the widgets.
  - `MacShell/GlassBlur.qml` is the outline of one surface. It finds its window's collector by walking up its parent items. This keeps the many popovers, Repeater banners and Control Center tiles from each needing the shell's hub passed down to them.
- **Following moves.** Quickshell's `Region` only watches its item's own x/y/size. `GlassBlur` also reads every ancestor's position, scale and opacity, and feeds them into the region's own x, y, width and height, which Quickshell ignores while an item is set. Any move, scale or fade then rebuilds the region. Quickshell applies blur-region changes once per frame (`BackgroundEffect::onWindowPolished`), so many surfaces animating together cost one rebuild per frame.
- **Hidden surfaces.** A surface whose total opacity is 5 % or less is left out. That covers fades and the 0.01-opacity warm-up of the desktop sheets.
- **The switch.** It is `MacDock.kwinBlur`, saved in `~/.config/macdock/settings.json`. The effective value is `hub.kwinBlur`, which also requires `compositor.can("backgroundEffect")`, so Hyprland and other compositors are unaffected and the switch is hidden there. While it's on:
  - `liquidActive` is false in the bar and the Dock, so every surface takes its existing flat fallback;
  - `LGlass`'s fallback uses the same see-through tint as `GGlass` and the Dock's Normal Blur (alpha = Translucency);
  - `DockGlassPanel` uses its live tint instead of the solid fill;
  - Liquid Glass widgets show their frosted card at about the Translucency setting.
- **Unchanged.** The bar-strip fill (Menu Bar → Bar background) is blurred by KWin with or without the option, as before. It now goes through the same collector.

## Setup

1. Enable System Settings → Desktop Effects → **Blur**. If you use Better Blur or another force-blur effect, turn off its force-blur of docks.
2. Fetch and start the branch:

```sh
git fetch && git switch kwin-replace-wallpaper-splash && git pull
macshell kill 2>/dev/null
nix develop --command qs -p ./MacShell      # Ctrl+C stops it
```

Open Settings → Appearance and check that **Use KWin's blur** is there, then turn it on. Put a busy window, for example Konsole full of text, behind each surface you test.

Rollback: turn the switch off, or `Ctrl+C`. The only file it writes is `~/.config/macdock/settings.json` (`kwinBlur`).

## Checks

For each surface, check three things:
- the window behind it shows through, **blurred**;
- the blur stops at the surface's rounded edge, with no rectangle around it and no full-screen blur;
- the blur disappears when the surface closes.

1. **Bar strip**, with Menu Bar → "Liquid Glass bar" on.
2. **Bar popovers:**
   - the app menu (global menu), the Apple menu and a tray menu;
   - the calendar, the keyboard-layout pop-over, volume, Wi-Fi and Bluetooth;
   - the notification centre.
3. **Control Center** in both styles: tiles, where each tile is its own glass, and "macOS", one slab.
4. **Notification banner:** `notify-send "Blur test" "hello"`.
5. **Other bar surfaces:**
   - Spotlight: `macshell ipc call spotlight toggle`;
   - the window switcher: `macshell ipc call switcher next`, then `cancel`;
   - the wallpaper picker: `macshell ipc call wallpapers toggle`;
   - the volume/brightness pop-up (hardware keys).
6. **Dock:** its background, a hover label and the right-click menu.
7. **Desktop:** the right-click menu and the Rename and Quick Preview sheets. Right after MacShell starts, there must be no blurred rectangles where the sheets warm up invisibly.
8. **Widgets:** a Liquid Glass Weather, Calendar, Clock or Player widget. Photo and solid-style widgets must stay unblurred.
9. **Animations:** open and close popovers and the Control Center several times. The blur follows them, nothing stutters, and no blurred patch is left behind.
10. **Translucency** (Appearance) changes the tint. Display scales above 100 % and fractional scaling still match the outlines.
11. **Switch off:** Liquid Glass comes back where the styles are Liquid Glass, no blur patches remain, and the bar-strip fill blur (Menu Bar → Bar background) still works.
12. **Restart:** the setting persists.
13. **Hybrid graphics:** the NVIDIA GPU stays suspended while you use the shell with the option on, the same as with it off.

## Results

| Check | Result (`pass` / `fail` / `partial`) | Evidence |
| --- | --- | --- |
| 1–8 surfaces | | |
| 9 animations | | |
| 10 translucency / scaling | | |
| 11 switch off, bar fill | | |
| 12 persistence | | |
| 13 NVIDIA stays asleep | | |

Treat the feature as complete only after these pass (AGENTS.md §12).
