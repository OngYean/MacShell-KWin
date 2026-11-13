# Second Plasma test report (2026-11-11): KWin blur defects, per-panel look, title

`AGENTS.md` remains the authority. This file continues [`15-plasma-test-report.md`](15-plasma-test-report.md): it lists what the user found on the next test of branch `pending-test` in a Plasma 6.8 Wayland session (KWin 6.8.2, a force-blur effect of the Better Blur family in use), the features they asked for, and what was done about each on 2026-11-11.

**State: committed on `pending-test` as six `wip` commits (`0ed468c` to `329d6df`) plus two docs commits, and pushed on 2026-11-11.** Nothing has run in Plasma.

## Items

| ID | Report or request (user's words, shortened) | Status |
| --- | --- | --- |
| B7 | Changing the Dock size still freezes the shell for a few seconds; better than before (B2). | fix written (`811fe32`) |
| B8 | With KWin's blur, the blurred area of Control Center elements, most of all the lower ones, sits vertically off the element. Probably the end of the opening animation isn't applied to the blur area. Find similar issues elsewhere. | fix written (`0ed468c`) |
| B9 | The Dock's KWin blur keeps re-rendering while it is hovered or magnified. | fix written (`0ed468c`, `d377fd1`) |
| B10 | With KWin's blur, a panel that should be transparent has a slight yellow tint. It gets stronger when the force-blur effect's brightness is raised. | diagnosed, no code change, needs confirmation |
| B13 | (2026-11-13) With KWin's blur chosen for the Dock, the Dock still re-renders the blur when right-clicking any Dock icon. | fix written |
| B11 | Settings has two options for showing pictures of minimized windows: the one added last session and one that was already there. | fix written (`8665cd9`) |
| F9 | Choose the blur (stock or KWin) for each shell element, for example stock for the Dock and KWin for the rest. | written (`33f6b58`) |
| F10 | Adjust the transparency of each panel separately (matters most with KWin's blur). | written (`33f6b58`) |
| F11 | A custom title for when no window is focused (now "Desktop"). | written (`329d6df`) |
| F14 | (2026-11-13) For blurring, decouple the Dock and its tooltip + right-click menu: the two can have their own blur options. | written |

Statuses as in [`15`](15-plasma-test-report.md): `fix written` / `written` = code exists, not run in Plasma.

## What was checked

- `qmllint` 6.12 (PySide6 wheel, syntax only) on the ten edited QML files: the same findings as at `021ae11`, apart from line numbers. `MacDock.qml` keeps its two old `duplicated id` errors.
- `node nix/test-panel-look.js` passes (new, added to the CI workflow), and `node nix/test-kde-colors.js` still passes.
- `git diff --check` is clean.
- Sources read: Quickshell `v0.3.2` (`src/core/region.cpp`, `src/wayland/background_effect/`), KWin `v6.8.2` (`src/plugins/blur/blur.cpp`, `src/scene/backgroundeffectitem.cpp`, `src/wayland/backgroundeffect_v1.cpp`, `src/backends/drm/drm_output.cpp`), Better Blur DX `main` (`src/blur.cpp`, `src/blur_cache.cpp`, `src/blur.kcfg`).
- Not checked: anything at run time. No Quickshell, KWin or Plasma on the development machine.

## Done: cause, change, test

**B7 Dock size.** The Size slider set `iconSize` at each of up to 96 steps of a drag. Each step changes `windowHeight`, so the Dock's layer surface is resized on every screen (a configure round trip and new buffers), and with "never hide" the reserved screen edge changes too, which makes KWin lay out every maximized window again. This was read from the code, not profiled. Change: a `LazySlider` in `MacDock.qml`. The knob follows the pointer, and the value is applied at most every 150 ms. Size and Magnification amount use it. The preview inside Settings follows at the same pace.
Test: drag Size and Magnification end to end, also with Dock → hiding set to never. If one step is still slow, note whether "never hide" makes it worse, and how many screens are connected.

**B8 blur out of place.** `GlassBlur` rebuilt a surface's blur outline only when an ancestor's `x`, `y`, `scale` or `opacity` changed. A `transform:` (Translate, Scale) was not watched; the comment there assumed the opacity always changes along with it. The Control Center's tiles slide up 16 px with `transform: Translate` while their opacity reaches 1 when the slide is 62 % done, so the outline stopped about 6 px short, and later rows, which start later, were left further off. Change (`GlassBlur.qml`): the outline now also reads every ancestor's size and each entry of its `transform` list, and is rebuilt exactly when the surface's rectangle in the window changes (computed with `mapToItem`, rounded the way Quickshell's `Region` rounds).
Same fault elsewhere, fixed by the same change:
- the Control Center's edit row (same animation as the tiles);
- the desktop's right-click menu (`transform: Scale` from 0.94 to 1, opacity at 1 when it is 55 % done);
- cards in the notification centre while they fly in or close a gap (`Translate` driven separately from the opacity), if the card is glass.

Still not handled, none of it seen in a report:
- a surface partly scrolled out of a clipped list is blurred over its whole rectangle;
- a rotated surface, or one whose `transformOrigin` changes;
- the blur does not fade with a panel: it is there from 5 % opacity on (the protocol has a region, no opacity).

Test: open and close the Control Center ten times in both styles with a busy window behind it; every tile's blur must sit exactly under the tile once it has settled. Then the desktop's right-click menu and the notification centre.

**B9 the Dock's blur re-rendering.** Two causes, both in how KWin's blur is fed.
1. `GlassBlur` also rebuilt the outline on every frame of a fade (it carried the opacity so that it would re-run). Each rebuild sends KWin a new region, even an identical one. Fixed by the B8 change: a fade alone no longer rebuilds anything.
2. KWin's blur sizes its off-screen textures by the bounding box of the window's whole blur region (`blur.cpp`: `textures[0]->size() != backgroundRect.size()` reallocates all of them), and Better Blur DX drops its cache at the same place ("New framebuffers required"). The Dock's box changed on every frame of magnification (the Dock widens) and each time a hover label appeared or left. Change: `BlurCollector` has a `holdRect`. The Dock sets it to the strip the Dock and its labels move in (full width, everything below the 300 px kept for the right-click menu), and two 1 px regions at its corners keep the box one size. The right-click menu still changed the box when it opened and closed: that is B13 below, which widens the hold to the whole window.

Known limits: those two pixels are blurred too, and KWin now blurs a full-width area for the Dock instead of the Dock's own rectangle, which is more GPU work per repaint of that area. If the Dock's blur is fine without it, set `holdRect` back to nothing in `MacDock.qml` (search `holdRect`).
Test: hover along the Dock with magnification on and off; the blur must not flicker or visibly redraw. Watch the GPU load while hovering, and that the NVIDIA GPU stays asleep. Where the two pixels are since B13: see there.

**B13 the Dock's blur re-rendering on right-click (2026-11-13).** The limit B9 left: the right-click menu opens in the 300 px of the Dock window above the held strip, so its outline made the blur's box taller when it appeared, again on the frames of its 110 ms pop-in (scale 0.96 to 1) where the rounded rectangle moved, and once more when it closed. Each change reallocates KWin's textures; stock KWin then clears them and refills only the damaged part, and Better Blur DX drops its cache. Checked again in the sources (KWin `v6.8.2` `blur.cpp`, Better Blur DX `main` `blur.cpp` / `blur_cache.cpp` / `window.cpp`): only a changed box size does this; a region that changes inside the same box does not. Change (`MacDock.qml`, one line): `holdRect` is the whole Dock window, so nothing in it can change the box.

Known limits:
- the two 1 px blurred dots are now at the window's top-left corner (screen's left edge, about 480 px above the bottom at the default Dock size and magnification) and at the bottom-right corner of the screen;
- the blur's textures cover the whole Dock window (about 480 px high instead of about 180), and a repaint anywhere under that area now runs the Dock's blur. Stock KWin runs its blur passes over the whole box each time, so this is about 2.6 times the pixels per pass at the default sizes; Better Blur DX limits them to the damaged part. This was not measured;
- to go back to the strip: `holdRect: Qt.rect(0, root.menuRoom, win.width, root.windowHeight - root.menuRoom)`.

Test: with the Dock on KWin blur and a busy window behind it, right-click several icons, move between menu rows, pick an item, and close the menu by clicking elsewhere: the Dock's blur must not flicker or redraw at any point, and the menu itself must be blurred. Repeat with magnification on. Look for the two dots. Play a video in a window that reaches the lower third of the screen and compare KWin's GPU load with the Dock on Stock blur; the NVIDIA GPU must stay asleep.

**B10 yellow tint: cause not in MacShell's drawing, nothing changed.** What MacShell paints on a panel with KWin's blur is a neutral tint (`rgba(0.10, 0.10, 0.11, a)` dark, white light), white or black hairlines, and one 1.25 px edge line in the wallpaper's dominant colour at 16 % (`MenuBorder.qml`). None of that depends on the blur effect's brightness. What does:
- KWin's blur multiplies what it blurred by a colour matrix: saturation 150 % by default (`blur.kcfg`), in Better Blur DX also contrast and then brightness (`colorTransformMatrix`). Grey stays grey through it; anything with a colour cast gets a stronger one.
- With Night Light on, KWin composites into a colour space whose white point is already warm (`drm_output.cpp`, `applyNightLight`), so every pixel the blur reads is orange-white. Raising its saturation lowers blue further, and a brightness above 100 % clips red and green at full while blue stays behind: yellow. This matches "stronger with more brightness". A warm wallpaper or window behind the panel does the same without Night Light.

This is a reading of the sources, not an observation. To confirm on the Plasma host, with a white window behind the Dock:
1. set the Dock's slider under Appearance → Panels to Clear (MacShell then paints only hairlines);
2. turn Night Light off: does the tint go?
3. set the blur effect's saturation and brightness to 100 %: does the tint go?

If the tint stays with all three, the cause is somewhere else: record the wallpaper, the blur effect's name and version, and a screenshot. If 2 or 3 removes it, there is nothing for MacShell to fix: KWin 6.8.2's blur has no per-window colour settings a client could send. `README.md` → Troubleshooting has the short version.

**B11 duplicate option.** "Minimized windows as pictures" (`minimizedSnapshots`, added for B6) is removed. "Show window previews" (`showThumbs`, from the original) now covers it: on KDE it means still pictures of minimized windows, elsewhere live previews of open windows, and its subtitle says which. "Live window capture" is hidden on KDE, where KWin offers none and the switch did nothing. A saved `minimizedSnapshots` is ignored. One behaviour change on KDE: with previews on, open windows of unpinned apps no longer get an extra app-icon cell; their app's own Dock icon already shows them.
Test: Settings → Desktop & Dock has one switch for this; off removes the minimized-window pictures, on brings them back.

**F9 blur per panel, F10 transparency per panel.** Settings → Appearance → Panels replaces the single "Use KWin's blur" switch. Nine rows, each with "Stock blur / KWin blur" (shown only where KWin's blur protocol exists) and a Clear-to-Solid slider:

| Key | Panel | Where it is applied |
| --- | --- | --- |
| `dock` | Dock (until F14 also its labels and right-click menu) | `MacDock.qml` (`kwinBlurOn`, `dockTint`) |
| `dockmenus` | Dock hover labels and right-click menu (F14, 2026-11-13) | `MacDock.qml` (`kwinBlurTips`, `tipsTintK`) |
| `bar` | Menu bar strip ("Liquid Glass bar") | `MacBar.qml`, `barGlassStrip` |
| `menus` | App menus, submenus, tray menu, calendar, keyboard layout, sound, Wi-Fi, Bluetooth | `MacBar.qml`, the default zone |
| `cc` | Control Center | `ccg` |
| `notifs` | Banners and the notification centre | `tslab`, `notifPopGlass` |
| `spotlight` | Spotlight | `spg`, `spotBackdrop` |
| `overlays` | Window switcher, wallpaper picker, volume / brightness pop-up | their `LGlass` and backdrop loaders |
| `desktop` | Desktop right-click menu and sheets | `Desktop.qml` |
| `widgets` | Liquid Glass widgets | `MacWidgets.qml` |

How it is built:
- `MacDock.qml` stores `panelBlur` (zone → true / false) and `panelTint` (zone → 0..1) in `~/.config/macdock/settings.json`. A zone that was never picked follows the old `kwinBlur` switch and the global `glassOpacity`, so existing settings keep their meaning. `kwinBlur` has no control any more.
- `MacShell/PanelLook.js` reads the two maps (tested by `nix/test-panel-look.js`). `shell.qml` offers them as `hub.kwinBlurFor(zone)` and `hub.panelTint(zone)`; `hub.kwinBlur` is gone.
- In `MacBar.qml`, `LGlass` and `GlassCtx` / `PopGlassCtx` have a `zone` property (default `menus`). Every site binds `liquid: root.liquidOf(zone)` and `tint: root.tintOf(zone)`. `liquidActive` now means "the bar's glass pipeline runs", which it does unless all six bar zones use KWin's blur. The backdrops of the switcher, wallpaper picker, level pop-up and Spotlight are not loaded while their zone uses KWin's blur.
- The floors on the default tint (dark menus at least 0.55, the frosted switcher at least 0.5) apply only while a panel has no value of its own. Because of that, an untouched "Menus and popovers" slider shows 0.42 in dark mode while the menus are drawn at 0.55; moving it takes the shown value as it is.
- The Dock's labels and menu, and the desktop's menu and sheets, have fixed tints; the slider scales them (`DockGlassPanel.tintK`, 1 at 0.42).
- Not covered by a slider: the bar's own background fill (it has "Bar background" under Menu Bar), and the knobs of switches and sliders.

Test:
1. Appearance → Panels shows nine rows (ten since F14). Set the Dock to Stock blur and everything else to KWin blur; each panel must follow its own row, right away.
2. With Dock style and Menu Bar style on Apple Liquid Glass, mix the choices: a Stock panel shows Liquid Glass, a KWin panel the tint with KWin's blur.
3. Move each slider from Clear to Solid: only that panel changes. At Clear with KWin blur, only the blur and the hairlines remain.
4. Restart MacShell: the choices persist. A settings file from before, with `"kwinBlur": true` and no `panelBlur`, shows every row on KWin blur.
5. With every panel on KWin blur, the NVIDIA GPU stays asleep and MacShell's GPU load is no higher than before.

**F14 the Dock's labels and menu apart from the Dock (2026-11-13).** Settings → Appearance → Panels has a tenth row, "Dock labels and menu" (zone `dockmenus`), with its own "Stock blur / KWin blur" choice and Clear-to-Solid slider, like every row. The "Dock" row now means the Dock itself.
- `PanelLook.js`: a zone that was split off follows the zone it came from until it is picked itself (`follows = { dockmenus: "dock" }`), for the blur and for the tint. A saved setting therefore looks the same as before until the new row is touched. `nix/test-panel-look.js` checks this.
- `MacDock.qml`: `kwinBlurTips` and `tipsTintK` feed the hover label and the right-click menu (both `DockGlassPanel`); `dockTintK` is gone. The old `liquidActive` is split: `liquidActive` (the Dock itself is Liquid Glass), `tipsLive` (its labels and menu are) and `glassPipe` (either: the wallpaper, the window positions and the backdrop they share).
- Consequence: with the Dock on KWin blur and the labels on Stock blur (Dock style Apple Liquid Glass), the Dock's backdrop (wallpaper plus window captures) keeps running for the labels and menu alone. Before, KWin blur on the Dock stopped it. With Dock style Normal Blur, "Stock blur" labels and menu are a solid fill, as they always were in that style.
- Settings → Desktop & Dock: "Dock style" says "not used" and "Real-time glass" hides only when both rows use KWin blur.
- B9 / B13 are unaffected: the held box belongs to the Dock's window, whichever of the two puts a region in it. The two 1 px dots and the window-sized blur textures are there whenever either row uses KWin blur, also while no label or menu shows (`BlurCollector` counts a surface that has KWin blur switched on, shown or not).

Checked: `node nix/test-panel-look.js` passes; `qmllint` 6.12 (syntax only) gives the same 732 findings on `MacDock.qml`, `MacBar.qml`, `Desktop.qml`, `shell.qml` as before. Not run in Plasma.

Test:
1. With settings from before (Dock on KWin blur, the new row never touched): the new row shows KWin blur and the Dock's slider value; labels and menu look as before.
2. Dock on Stock blur, labels and menu on KWin blur, Dock style Apple Liquid Glass: the Dock is Liquid Glass; a hover label and the right-click menu are a tint with KWin's blur behind them, and the Dock's glass does not flicker when they appear.
3. The reverse (Dock KWin, labels and menu Stock), Dock style Apple Liquid Glass: labels and menu show MacShell's own blurred glass with the right picture behind them; the Dock has KWin's blur. Watch MacShell's GPU load and that the NVIDIA GPU stays asleep.
4. The reverse with Dock style Normal Blur: labels and menu are solid.
5. Each row's slider changes only its own panel. Restart MacShell: both choices persist.

**F11 title without a window.** Settings → Menu Bar → "Title without a window": a text field, at most 40 characters, saved as `desktopTitle` in `~/.config/macbar/settings.json`. Empty means "Desktop". The generic menus for the desktop ("About …") use the same name.
Test: type a name, click the desktop: the bar shows it; clear the field: "Desktop" again.

## Left for the next session

- Run all of the above in Plasma and fill in results; B10's three checks first, since they decide whether anything is left to do there.
- **CI has not run any of this.** The push of `cbb76c1` (run `42931852560`) and the push of `021ae11` the day before (run `42774440253`) both show "failure" after two seconds with no steps: GitHub's annotation says "The job was not started because your account is locked due to a billing issue." So the commits of [`15`](15-plasma-test-report.md) and of this file are unbuilt, the bridge change for B6 (`3a9ac7b`) has still never been compiled, and the last real CI pass is `3a1e8a9` (2026-11-05). Once the account is unlocked, re-run the latest run (or push again) and read `https://api.github.com/repos/OngYean/MacShell-KWin/actions/runs?branch=pending-test`; a job's reason is at `/check-runs/<job id>/annotations`. CI builds the package, runs `node nix/test-panel-look.js` and loads MacShell under a headless KWin, so a QML load error in the new code would show there.
- Every code commit is `wip(...)`. Do not relabel any of them until its test above has passed in Plasma (`AGENTS.md` §12).
- Still open from [`15`](15-plasma-test-report.md): B5 (slow return after unlocking) and the Plasma tests of B1–B6 and F1–F8.
