# Project: Port MacShell to KDE Plasma Wayland + KWin, with Declarative Nix Integration

You are acting as a senior Linux desktop, Wayland, Qt/QML, Quickshell and Nix engineer.

I want to develop a macOS Tahoe-inspired desktop shell based on the existing **MacShell Quickshell project**, but I do not want to use Hyprland as my compositor. My target is **KDE Plasma Wayland with KWin**, retaining KDE's underlying desktop infrastructure while replacing its conventional desktop presentation with Quickshell.

This is a substantial architectural adaptation, not simply a theming exercise.

Your job is to inspect the existing repositories and environment, design a maintainable architecture, and progressively implement the port.

## 1. Core objectives

There are two non-negotiable reasons for retaining KDE Plasma's underlying infrastructure:

### A. KWin and Klassy

I want to retain KWin as my Wayland compositor because of its mature compositing capabilities and its compatibility with Klassy.

Klassy is essential to the visual design. I intend to use it to reproduce macOS-like application window decorations, including rounded corners, title bars, traffic-light-style window controls, shadows and other decoration details.

Requirements:

- Retain KWin as the compositor.
- Preserve KDecoration3 and Klassy compatibility.
- Do not replace KWin with Hyprland, Sway or another compositor.
- Do not introduce a competing window-decoration implementation.
- Preserve KWin's existing effects, blur, shadows and window-management functionality wherever possible.

### B. KDE Global Menu

KDE Plasma has particularly good global-menu integration.

I want to retain compatibility with KDE's application-menu infrastructure and expose application menus through a macOS-style top menu bar.

Important distinction:

- KWin's AppMenu Wayland integration and application-side D-BusMenu exports should remain usable.
- Plasma's existing Global Menu widget is part of the plasmashell presentation layer.
- Replacing plasmashell means we need an alternative menu renderer or a temporary arrangement that preserves the native Plasma widget.

Investigate the exact protocols, D-Bus interfaces, application-menu registration mechanisms and KWin APIs available in the installed Plasma version.

Do not assume that rendering a generic menu bar is sufficient. The goal is to display the actual active application's exported menu.

Test compatibility with Qt, GTK, Electron, Firefox and VS Code. Treat native Wayland and Xwayland as separate test cases where relevant.

## 2. Target architecture

The desired architecture is:

```text
                 Quickshell
             Custom MacShell fork
                      |
        +-------------+-------------+
        |             |             |
     MacBar        MacDock       Widgets
        |             |             |
    Global Menu   App launcher   Desktop UI
    Control Center Previews      Wallpaper
    Notifications  Task state
        |
        v
          KDE / KWin integration
                      |
        +-------------+-------------+
        |             |             |
       KWin        KDE services   D-Bus
        |             |             |
     Klassy        PowerDevil     Portals
     Effects       KDED          Polkit
     Compositor    KIO           PipeWire
        |
        v
             Wayland session
```

This is a conceptual architecture, not a requirement to implement every component in one QML process.

The objective is to replace the visual shell without discarding the underlying KDE desktop infrastructure.

Do not conflate `plasmashell` with the entire Plasma session.

## 3. Repository inspection and discovery

Before changing anything, inspect the current workspace.

Identify:

1. The Nix configuration repository and its structure.
2. Whether Home Manager or NixOS modules are used.
3. Existing Nix flakes, overlays, package definitions and pinned inputs.
4. Whether a MacShell checkout or fork already exists.
5. The MacShell upstream revision and its actual QML structure.
6. The installed or configured versions of KDE Plasma, KWin and Quickshell, where discoverable.
7. Existing desktop autostart and session configuration.
8. Existing Klassy installation and configuration.

Do not assume that the current repository structure matches an example layout.

Inspect the actual MacShell source rather than relying on documentation or assumptions about its internal implementation.

Produce an inventory of all Hyprland-specific dependencies.

Pay particular attention to:

- Hyprland QML imports.
- Hyprland IPC.
- Hyprland Lua dispatch.
- Workspace and window enumeration.
- Window activation and focus.
- Window previews and capture.
- Output management.
- Session management.
- Lock-screen integration.
- Compositor-specific effects.
- Any hardcoded Hyprland environment variables or executable paths.

Classify each dependency as:

- Purely visual and reusable.
- Compositor-independent Wayland functionality.
- Hyprland-specific functionality that needs a KWin equivalent.
- KDE-specific functionality that needs new integration.

Do not start with a large rewrite.

First establish which portions of the original UI can be retained unchanged.

## 4. Porting architecture

I want a clean separation between the UI and compositor integration.

Introduce a backend abstraction so that the presentation layer does not directly depend on Hyprland APIs.

A possible structure:

```text
MacShell/
├── shell.qml
├── components/
│   ├── MacBar.qml
│   ├── MacDock.qml
│   ├── MacWidgets.qml
│   └── ...
├── backends/
│   ├── compositor/
│   │   ├── Compositor.qml
│   │   ├── KWinBackend.qml
│   │   └── HyprlandBackend.qml
│   └── globalmenu/
│       ├── AppMenu.qml
│       └── DBusMenu.qml
└── services/
    ├── Applications.qml
    ├── Notifications.qml
    └── ...
```

This is a suggested structure. Adapt it to the actual project rather than restructuring files unnecessarily.

The interface between the UI and compositor backend should eventually support:

### Window management

- Active window identification.
- Window enumeration.
- Window title, application ID, icon and geometry.
- Window activation and focus.
- Minimize, maximize, close and fullscreen.
- Window state changes.

### Workspace management

- Workspace enumeration.
- Active workspace identification.
- Workspace switching.
- Moving windows between workspaces.
- Workspace changes reflected in the dock and UI.

### Display management

- Monitor enumeration.
- Monitor geometry and scale.
- Multi-monitor placement of panels and docks.
- Hotplug handling.

### Window previews

- Window thumbnail capture.
- Window previews in the dock.
- Application switching and window selection.

### Session integration

- Lock screen.
- Logout, reboot and shutdown.
- Suspend and resume.

Use supported KWin interfaces and protocols where possible.

Investigate KWin scripting, D-Bus, KDE-specific Wayland protocols and available window-management interfaces before choosing an implementation.

Do not assume KWin exposes every Hyprland feature through a direct equivalent.

Where functionality requires a KWin script, separate helper or external service, keep it isolated from the main QML presentation layer.

Avoid depending on undocumented private interfaces unless there is a compelling reason and the dependency is explicitly documented.

## 5. Global Menu implementation

Treat this as an early proof-of-concept milestone.

Investigate:

- KWin's application-menu Wayland protocol.
- KDE's application-menu registration and D-Bus interfaces.
- D-BusMenu model retrieval and event handling.
- How Plasma's Global Menu widget obtains active-window menu information.
- Whether existing reusable KDE libraries or QML components can be used.
- Whether a Quickshell implementation already exists and is compatible with the target versions.

The desired result is:

```text
Active application
       |
       v
Application menu export
       |
       v
KWin / KDE AppMenu integration
       |
       v
MacShell global menu renderer
       |
       v
macOS-style top menu bar
```

The renderer should support:

- Application identity and name.
- Menu hierarchy and nested submenus.
- Separators.
- Disabled menu items.
- Checkable menu items.
- Keyboard shortcuts.
- Menu activation events.
- Menu updates when the active window changes.
- Correct handling of application focus changes.

Do not implement a static visual mockup and consider global menu support complete.

For the initial proof of concept, it is acceptable to retain a minimal Plasma panel containing the native Global Menu widget while Quickshell owns the remaining desktop UI.

However, the eventual objective is to implement a standalone renderer so that plasmashell is no longer required for the global menu.

## 6. Preserve KDE desktop services

Do not remove KDE components merely because they are not visually part of the new shell.

Preserve and verify functionality involving:

- KWin and its effects.
- Klassy.
- KDED services.
- Session management.
- PowerDevil.
- KDE authentication and Polkit integration.
- KIO and KDE Frameworks.
- XDG desktop portals.
- Screen sharing.
- Screenshot functionality.
- PipeWire and WirePlumber.
- NetworkManager.
- Bluetooth.
- Clipboard integration.
- Screen locking.
- Notifications.
- System tray integration.

Pay particular attention to services that are currently provided by plasmashell itself.

For example, do not assume that notifications, the StatusNotifierItem watcher or the desktop lock screen will continue functioning identically after replacing the shell.

Identify ownership and dependencies for each feature before disabling any existing component.

Do not introduce duplicate notification daemons, tray watchers or other desktop services.

Keep KDE's native screen-locking and session-security infrastructure until an alternative has been proven reliable.

## 7. Nix integration

The source-code port and Nix configuration should remain separate responsibilities.

### MacShell fork

The fork should own:

- QML implementation.
- KWin backend.
- Global menu implementation.
- Compositor abstraction.
- UI modifications.
- Project-specific documentation.

Keep upstream as a remote and maintain a dedicated KWin porting branch.

Preserve upstream attribution and licensing.

### Nix configuration

The Nix repository should own:

- Quickshell installation.
- Required runtime dependencies.
- Pinned MacShell source.
- QML configuration deployment.
- KDE configuration.
- Klassy installation and configuration.
- GTK and Qt themes.
- Icon themes and fonts.
- Desktop autostart.
- User-level service management.
- Relevant environment variables.

Use existing Nixpkgs packages wherever possible.

Only introduce custom derivations when existing packages are insufficient.

For an initial setup, consider a separately pinned flake input for the MacShell fork:

```nix
inputs = {
  macshell-src = {
    url = "github:YOUR_USERNAME/MacShell/kwin-port";
    flake = false;
  };
};
```

This is illustrative. Replace it only after identifying the actual repository and desired source revision.

Pin dependencies through the existing flake lock.

Do not introduce an entirely new Nix configuration structure when the current repository already has an established convention.

Inspect the existing Home Manager version before relying on particular module options.

If Quickshell can load the QML configuration directly from a directory, prefer that during development rather than unnecessarily compiling or copying everything into a custom package.

The final deployment must be reproducible and declarative.

Do not rely on running an imperative installation script during normal deployment.

## 8. Development environment considerations

The target environment is KDE Plasma Wayland with KWin.

The laptop uses hybrid AMD/NVIDIA graphics, with an AMD integrated GPU and NVIDIA RTX 3050 Laptop GPU.

Avoid introducing unnecessary discrete-GPU wakeups.

In particular:

- Avoid unconditional background capture.
- Avoid unnecessarily expensive window-preview rendering.
- Make live previews optional.
- Investigate Quickshell's graphics backend and GPU selection.
- Verify that ordinary shell rendering does not unnecessarily activate NVIDIA.
- Do not change existing KWin DRM device selection or hybrid graphics configuration without a demonstrated need.

Also account for:

- HiDPI scaling.
- Fractional scaling.
- Multiple monitors.
- Display hotplug.
- Sleep and resume.
- Battery consumption.
- Session restart and crash recovery.

## 9. Implementation milestones

Work incrementally.

### Milestone 1: Architecture audit

Inspect the repositories and produce:

1. A dependency inventory.
2. A list of Hyprland-specific components.
3. A KWin compatibility assessment.
4. A global-menu implementation assessment.
5. A proposed backend architecture.
6. A proposed Nix integration plan.
7. A list of technical blockers and uncertain assumptions.

Do not modify the host desktop session at this stage.

### Milestone 2: Minimal KWin proof of concept

Get a minimal Quickshell configuration running in an existing Plasma Wayland session.

Verify:

- Quickshell starts under KWin.
- A basic top panel works.
- A basic dock works.
- Correct Wayland layer placement is achieved.
- Existing KWin window decorations remain intact.
- Klassy continues to function.

Keep plasmashell running during this stage.

Avoid overlapping panels and docks.

### Milestone 3: Compositor abstraction

Introduce and implement the KWin backend.

Get basic window enumeration, active-window tracking, workspace information and application activation working.

Keep unsupported features explicitly marked rather than silently providing incorrect behaviour.

### Milestone 4: Global Menu proof of concept

Implement or integrate the KDE AppMenu/D-BusMenu renderer.

Verify actual interaction with supported applications.

Compare the result against Plasma's native Global Menu widget.

### Milestone 5: Full MacShell integration

Port the remaining UI and compositor-dependent functionality.

Prioritise:

1. Menu bar.
2. Dock.
3. Global Menu.
4. Control Center.
5. Application launcher.
6. Window switching and previews.
7. Notifications.
8. Widgets.
9. Lock screen and remaining session features.

### Milestone 6: Nix deployment

Package and configure the finished implementation declaratively.

Preserve the original Plasma session as a fallback.

Provide a reliable way to switch between the original Plasma shell and the new Quickshell implementation.

Do not permanently disable plasmashell until the replacement is sufficiently complete.

## 10. Acceptance criteria

The project should not be considered complete until these conditions are verified:

- KDE Plasma Wayland session starts normally.
- KWin remains the active compositor.
- Klassy continues providing window decorations.
- macOS-style Quickshell menu bar and dock render correctly.
- Global menus display real application menus, not static mockups.
- Application activation and window management work.
- Workspaces and multiple displays work correctly.
- Polkit authentication prompts work.
- Notifications and system tray functionality work.
- Screen sharing and screenshots work.
- Native screen locking and session management remain functional.
- Sleep, resume and display hotplug do not break the shell.
- No unnecessary NVIDIA GPU wakeups are introduced.
- The configuration can be reproduced through Nix.
- The original Plasma desktop remains recoverable.

## 11. Working rules

Follow these rules throughout development:

1. Inspect before editing. Do not guess the repository structure or invent existing APIs.
2. Verify the installed and target software versions. Do not assume the latest upstream API matches the local environment.
3. Prefer upstream documentation, source code and working examples over assumptions.
4. Keep changes small and logically separated.
5. Preserve upstream functionality wherever possible.
6. Do not rewrite the entire MacShell project merely to introduce a KWin backend.
7. Do not remove KDE packages or disable desktop services without understanding their responsibilities.
8. Do not make irreversible changes to the host session.
9. Do not run privileged installation or configuration commands without explicit approval.
10. Do not make unrelated changes to my Nix configuration.
11. Record important technical decisions and explain why a particular KWin integration method was selected.
12. Document unsupported features and workarounds honestly.
13. Run relevant tests and validate QML syntax after modifications.
14. Maintain a clear rollback path throughout development.
15. Keep the README's comparison with the original project current. `README.md` must list the features **added**, **modified** and **removed** (including those unavailable on KDE Plasma) compared to the original MacShell (https://github.com/0-ss/MacShell; this fork is based on its commit `51db0ba`). Every change that adds, changes, removes or disables a user-visible feature updates that list in the same branch, and says honestly whether the behaviour has been tested in Plasma. When upstream changes are merged, update the base commit and re-check the whole list.

When uncertain about a KWin or Quickshell API, investigate it rather than inventing an interface.

If the source fork is not available in the workspace, identify the correct upstream repository and propose the cleanest way to obtain the fork. Do not invent repository URLs or claim to have created a GitHub fork without actually doing so.

## 12. Git and commit rules

Follow these rules whenever Git changes are made:

1. Commit only when the user explicitly requests commits. Do not create branches, amend commits, rebase, force-push, or rewrite published history unless explicitly requested.
2. Before staging, inspect `git status` and the diff. Preserve all existing user changes. Stage explicit paths for the current logical change; never use blanket staging such as `git add -A` when unrelated or untracked user files may exist.
3. Use Conventional Commit-style subjects: `<type>(<scope>): <imperative summary>`. Keep the subject concise and descriptive. Common types include `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `chore`, and `wip`. Examples:
   - `feat(kwin): add active-window backend adapter`
   - `docs(global-menu): record AppMenu protocol findings`
   - `build(nix): package the development shell`
4. Keep each commit small, atomic, and reviewable: one logically related change per commit. Separate handoffs/docs, Nix packaging, runtime code, tests, and unrelated formatting into distinct commits where practical. Avoid drive-by formatting and unrelated cleanup.
5. Do not let a commit subject or body imply functionality that has not been validated. For implementation code that is incomplete or cannot be tested in its required environment, use a `wip(<scope>): ...` subject. In the commit body, record:
   - `Status:` what is implemented and what remains incomplete.
   - `Validation:` exact commands run and their results, or `not run`.
   - `Reason:` why validation is unavailable (for example, the development session is Hyprland rather than Plasma/KWin).
   - `Follow-up:` the specific test or work required before treating it as complete.
6. A syntax check, flake evaluation, or build is not a runtime test. State these separately. Until actual KWin/Plasma behavior is tested, do not label the feature `feat`/`fix` as complete or claim it works under KWin. Documentation-only commits may use `docs` when they accurately describe the unverified status.
7. Before every commit, inspect the staged diff and run `git diff --cached --check`. Stage and commit one logical file group at a time; verify `git status` afterwards to ensure no unrelated changes were included.

## 13. Expected first response

Start with Milestone 1.

Inspect the available workspace and report:

- What repositories and configuration files you found.
- How MacShell currently depends on Hyprland.
- Which components can be reused unchanged.
- Which components need a KWin implementation.
- How KDE Global Menu can be retained or reimplemented.
- Any major architectural obstacles.
- The recommended initial changes.

Then proceed with safe, incremental implementation wherever the necessary source and dependencies are available.

The ultimate goal is not to recreate macOS at the expense of KDE functionality.

It is to build a polished, macOS Tahoe-inspired desktop shell that uses Quickshell for presentation while retaining KWin, Klassy and KDE's superior application-menu integration as its foundation.
