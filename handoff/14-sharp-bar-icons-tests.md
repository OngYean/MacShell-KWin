# Test plan: sharp menu bar icons at any scale

`AGENTS.md` remains the authority, and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) has the general runbook. On 2026-11-05 the user reported that the bar's icons go blurry when the UI scale changes. Committed straight to `pending-test` (`wip(bar): paint the bar's glyphs at the scale they are shown at`).

Written on macOS without Quickshell or Plasma. Done there: braces balance as before; the new `Glyph` binding and `draw()` parse with `node --check`; `draw()` runs for all 54 glyph kinds in a Node mock without a `ReferenceError`. **Not run:** qmllint, CI and every check below.

## Cause

- The status and popover icons aren't image files. They're the `Glyph` component in `MacShell/MacBar.qml`: Canvas bitmaps painted at their own 15–18 px times the screen's pixel density. Only the Apple logo is an SVG; it's loaded at 128×160 with mipmaps and was already sharp.
- The bar's left, centre and right rows are laid out at 28 px, then resized with `scale: root.barWidgetScale` (bar height ÷ 28 × UI scale). Popovers and the Control Center use `barPopupScale`. A `scale:` transform stretches a finished bitmap, so the icons blurred at any factor but 1. That includes automatic UI scale on screens smaller than 1920×1080 logical pixels, for example a 1920×1080 laptop at 125 %. Text stayed sharp: Qt Quick draws it as distance fields.
- Qt's Canvas reads the pixel density only when it paints, and doesn't repaint when it changes (`qquickcanvasitem.cpp` at Qt v6.12.0 handles `ItemSceneChange` only). After a display-scale change, an icon kept its old bitmap until its state changed.

## Fix

- `Glyph` is now an `Item`. Its inner `Canvas` is the glyph's size times its ancestors' scale (rounded to 5 % steps) and scaled back by the same factor, so each bitmap pixel lands on one screen pixel.
  - The glyph's own `scale:` isn't included. The Control Center's press animation (1 → 0.78 → 1) stays a transform instead of repainting.
  - An opening popover (scale 0.97 → 1) repaints once.
- The canvas also repaints when `Screen.devicePixelRatio` or the screen's logical size changes. A new KDE display scale changes both, or at least the size.
- Tray icons are loaded at 64×64 with mipmaps instead of 32×32.
- None of the 43 call sites changed. None of them used Canvas-only API.

## Checks

1. **Default settings, 100 % display scale:** the bar looks as before. Same icon sizes and positions, no clipping. The Wi-Fi bars, volume level and battery still update.
2. **UI scale** (Settings → Menu Bar): set it to 80 %, then 125 %, then back to 100 %. At each step the Wi-Fi, Bluetooth, volume, bell, search and Control Center icons are as crisp as the clock's text, with no soft edges. Zoom in with KWin's Zoom effect (`Meta+=`) to compare.
3. **Bar height** slider at its minimum and maximum: icons stay crisp.
4. **Popovers:** open the Control Center, the volume and Wi-Fi popovers and the notification list. Their icons are crisp, the open animation is smooth, and pressing a Control Center tile still animates its icon.
5. **Display scale:** in System Settings → Display, change the scale (100 % → 125 % → 150 %) without restarting MacShell. Icons are crisp after each change, without hovering or clicking anything.
6. **Several screens with different scales:** icons are crisp on each screen's bar.
7. **Tray:** tray icons (for example Steam, Discord or KDE Connect) are crisp at 100 % and 125 % UI scale and aren't jagged at 80 %.
8. **Cost:** with the bar idle, `top -p $(pgrep -f 'qs .*macshell' | head -1)` shows no new CPU use. Opening and closing popovers feels the same as before.

## Results to report

Pass or fail for each step, with a screenshot pair for step 2 (before this commit and after) if anything still looks soft. Note the display scale and the UI scale shown in Settings.
