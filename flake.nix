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
        in
        {
          default = macshell-hyprland;
          inherit macshell-hyprland;
        }
      );

      apps = forAllSystems (
        system:
        let
          package = self.packages.${system}.macshell-hyprland;
          app = {
            type = "app";
            program = "${package}/bin/macshell-hyprland";
            meta = package.meta;
          };
        in
        {
          default = app;
          macshell-hyprland = app;
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
            ];
          };
        }
      );
    };
}
