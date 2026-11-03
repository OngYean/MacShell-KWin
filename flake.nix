{
  description = "MacShell Quickshell shell: Hyprland, and a KDE Plasma (KWin) port in development";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          macshell-hyprland = pkgs.stdenvNoCC.mkDerivation {
            pname = "macshell-hyprland";
            version = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./MacShell/VERSION);
            src = ./MacShell;
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/bin" "$out/share/quickshell/MacShell"
              cp -R ${./MacShell}/. "$out/share/quickshell/MacShell/"
              # -p takes a path (-c takes a config *name*); LiveWall.qml imports QtMultimedia, which Quickshell's wrapper lacks
              makeWrapper ${pkgs.quickshell}/bin/qs "$out/bin/macshell-hyprland" \
                --add-flags "-p $out/share/quickshell/MacShell" \
                --prefix QML_IMPORT_PATH : "${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtQmlPrefix}" \
                --prefix QT_PLUGIN_PATH : "${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtPluginPrefix}"
              runHook postInstall
            '';

            meta = {
              description = "MacShell Quickshell configuration for Hyprland";
              mainProgram = "macshell-hyprland";
              platforms = systems;
            };
          };

          # KWin side of the compositor backend (MacShell/backends/compositor/KWinBackend.qml); see kwin-bridge/README.md
          macshell-kwin-bridge = pkgs.stdenv.mkDerivation {
            pname = "macshell-kwin-bridge";
            version = "0.1.0";
            src = ./kwin-bridge;
            nativeBuildInputs = [
              pkgs.cmake
              pkgs.pkg-config
              pkgs.qt6.wrapQtAppsHook
            ];
            buildInputs = [
              pkgs.kdePackages.kwayland
              pkgs.qt6.qtbase
              pkgs.wayland
            ];
            meta = {
              description = "MacShell's KWin bridge: windows, workspaces, keyboard layouts and the global menu over JSON lines";
              mainProgram = "macshell-kwin-bridge";
              platforms = systems;
            };
          };

          # The shell for KWin (and Hyprland: the backend is detected at start). Runs the configuration from the store;
          # `macshell ipc call ...` reaches the running instance. QtMultimedia is not in Quickshell's own wrapper but
          # LiveWall.qml (loaded by the Dock, Desktop and widgets) imports it.
          macshell = pkgs.stdenvNoCC.mkDerivation {
            pname = "macshell";
            version = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./MacShell/VERSION);
            src = ./MacShell;
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/share/macshell"
              cp -R ${./MacShell}/. "$out/share/macshell/"
              install -Dm755 ${./nix/macshell.sh} "$out/libexec/macshell"
              install -Dm755 ${./nix/macshell-session.sh} "$out/libexec/macshell-session"
              makeWrapper "$out/libexec/macshell" "$out/bin/macshell" \
                --set MACSHELL_CONFIG "$out/share/macshell" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.quickshell macshell-kwin-bridge ]} \
                --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.dbus pkgs.procps pkgs.gawk ]} \
                --prefix QML_IMPORT_PATH : "${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtQmlPrefix}" \
                --prefix QT_PLUGIN_PATH : "${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtPluginPrefix}"
              makeWrapper "$out/libexec/macshell-session" "$out/bin/macshell-session" \
                --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath [ macshell-kwin-bridge ]}" \
                --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.util-linux pkgs.gnused pkgs.gnugrep pkgs.coreutils ]}
              runHook postInstall
            '';

            meta = {
              description = "MacShell, a macOS-style Quickshell shell, for KDE Plasma (KWin) and Hyprland";
              mainProgram = "macshell";
              platforms = systems;
            };
          };

          kwin-backend-probe = pkgs.stdenv.mkDerivation {
            pname = "macshell-kwin-backend-probe";
            version = "0.2.0";
            src = ./poc/kwin-backend-probe;
            nativeBuildInputs = [
              pkgs.cmake
              pkgs.pkg-config
              pkgs.qt6.wrapQtAppsHook
            ];
            buildInputs = [
              pkgs.kdePackages.kwayland
              pkgs.qt6.qtbase
              pkgs.wayland
            ];
            meta = {
              description = "KWin Plasma Window Management diagnostic and isolated AppMenu bridge";
              mainProgram = "macshell-kwin-backend-probe";
              platforms = systems;
            };
          };
        in
        {
          default = macshell-hyprland;
          inherit macshell-hyprland macshell macshell-kwin-bridge kwin-backend-probe;
        }
      );

      apps = forAllSystems (
        system:
        let
          package = self.packages.${system}.macshell-hyprland;
          probe = self.packages.${system}.kwin-backend-probe;
          shell = self.packages.${system}.macshell;
          bridge = self.packages.${system}.macshell-kwin-bridge;
          app = {
            type = "app";
            program = "${package}/bin/macshell-hyprland";
            meta = package.meta;
          };
          probeApp = {
            type = "app";
            program = "${probe}/bin/macshell-kwin-backend-probe";
            meta = probe.meta;
          };
        in
        {
          default = app;
          macshell-hyprland = app;
          kwin-backend-probe = probeApp;
          macshell = {
            type = "app";
            program = "${shell}/bin/macshell";
            meta = shell.meta;
          };
          macshell-session = {
            type = "app";
            program = "${shell}/bin/macshell-session";
            meta = shell.meta;
          };
          kwin-bridge = {
            type = "app";
            program = "${bridge}/bin/macshell-kwin-bridge";
            meta = bridge.meta;
          };
        }
      );

      # Home Manager: programs.macshell (see nix/home-manager.nix)
      homeManagerModules = {
        macshell = import ./nix/home-manager.nix self;
        default = self.homeManagerModules.macshell;
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.quickshell
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qtmultimedia
              pkgs.python3 # kwin-bridge/fake-bridge.py
              pkgs.shellcheck
              pkgs.cmake
              pkgs.pkg-config
              pkgs.kdePackages.kwayland
              pkgs.wayland
              self.packages.${system}.kwin-backend-probe
              self.packages.${system}.macshell-kwin-bridge
            ];
            # `qs -p ./MacShell` straight from the work tree (LiveWall.qml needs QtMultimedia)
            QML_IMPORT_PATH = "${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtQmlPrefix}";
          };
        }
      );
    };
}
