# Home Manager module for MacShell on KDE Plasma (KWin).
#
#   imports = [ inputs.macshell.homeManagerModules.macshell ];
#   programs.macshell.enable = true;          # installs macshell + macshell-session, defines macshell.service
#   programs.macshell.autostart = true;       # optional: start it with every Plasma session
#
# plasmashell is never disabled here: MacShell starts next to it ("coexist"). Switching plasmashell off is a per-login,
# reversible action (macshell-session replace / restore), never configuration.
self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.macshell;
in
{
  options.programs.macshell = {
    enable = lib.mkEnableOption "MacShell, the macOS-style Quickshell shell (KDE Plasma / KWin port)";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.macshell;
      defaultText = lib.literalExpression "macshell.packages.\${system}.macshell";
      description = "The MacShell package: the Quickshell configuration, Quickshell and the KWin bridge.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start MacShell with every KDE Plasma session (macshell.service, wanted by plasma-workspace.target, so other
        sessions are unaffected). plasmashell keeps running; MacShell then runs in coexist mode.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Defined even without autostart, so `macshell-session start|stop|replace|restore` can drive it.
    systemd.user.services.macshell = {
      Unit = {
        Description = "MacShell (Quickshell desktop shell)";
        PartOf = [ "graphical-session.target" ];
        # after plasmashell, so a coexisting plasmashell owns its notification / OSD names first
        After = [ "graphical-session.target" "plasma-plasmashell.service" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/macshell";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = lib.mkIf cfg.autostart { WantedBy = [ "plasma-workspace.target" ]; };
    };
  };
}
