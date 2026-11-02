{
  description = "MacShell Quickshell package (current Hyprland backend; KWin port in development)";

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
              makeWrapper ${pkgs.quickshell}/bin/qs "$out/bin/macshell-hyprland" \
                --add-flags "-c $out/share/quickshell/MacShell"
              runHook postInstall
            '';

            meta = {
              description = "MacShell Quickshell configuration for Hyprland";
              mainProgram = "macshell-hyprland";
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
          inherit macshell-hyprland kwin-backend-probe;
        }
      );

      apps = forAllSystems (
        system:
        let
          package = self.packages.${system}.macshell-hyprland;
          probe = self.packages.${system}.kwin-backend-probe;
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
        }
      );

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
              pkgs.shellcheck
              pkgs.cmake
              pkgs.pkg-config
              pkgs.kdePackages.kwayland
              pkgs.wayland
              self.packages.${system}.kwin-backend-probe
            ];
          };
        }
      );
    };
}
