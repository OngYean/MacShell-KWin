# Home Manager module for MacShell on KDE Plasma (KWin).
#
#   imports = [ inputs.macshell.homeManagerModules.macshell ];
#   programs.macshell.enable = true;          # installs macshell + macshell-session, defines macshell.service
#   programs.macshell.autostart = true;       # optional: start it with every Plasma session
#   programs.macshell.mode = "coexist";       # optional: next to plasmashell instead of in its place (the default)
#   programs.macshell.lockScreen = true;      # optional: MacLock as KDE's lock screen (KDE still does the locking)
#
# plasmashell is never masked, removed or disabled. With autostart in "replace" mode a drop-in makes its unit skip
# itself while MACSHELL_KDE_MODE=replace is in the user manager's environment (set here for every login). For the
# current login `macshell-session coexist` (or `stop`) unsets it and starts plasmashell again, and so does
# macshell-fallback.service when MacShell keeps failing. mode = "coexist", autostart = false or enable = false bring
# Plasma's shell back at every login.
self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.macshell;
  systemctl = "${pkgs.systemd}/bin/systemctl";
  lockPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.macshell-lock;
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
        sessions are unaffected). `mode` decides whether plasmashell starts too.
      '';
    };

    mode = lib.mkOption {
      type = lib.types.enum [ "replace" "coexist" ];
      default = "replace";
      description = ''
        How autostart runs MacShell.
        "replace": plasmashell is skipped at login and MacShell takes its place (wallpaper, notifications). If
        MacShell fails three times within a minute, plasmashell is started instead.
        "coexist": plasmashell starts as usual and MacShell runs next to it.
        `macshell-session start` (replace) and `macshell-session coexist` switch the current login either way.
      '';
    };

    lockScreen = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Show MacLock as KDE's lock screen. KDE keeps locking the session itself (the password check through PAM,
        locking when idle and before sleep, restarting the screen after a crash); only what it draws changes, and if
        MacLock fails to load KDE shows its built-in fallback screen.
        Installs the Plasma/Shell package com.macshell.lock into the user's data directory and names it in
        PLASMA_DEFAULT_SHELL, so it applies from the next login. plasmashell and the logout screen read the same
        variable; the package holds nothing but the lock screen, so they take everything from Plasma's own package.
        A ShellPackage entry in plasmashellrc's [Shell] group overrides the variable.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [ cfg.package ];

      # Defined even without autostart, so `macshell-session start|coexist|stop` can drive it. Its mode comes from
      # MACSHELL_KDE_MODE in the user manager's environment (no Environment= here, so macshell-session can change it).
      systemd.user.services.macshell = {
        Unit = {
          Description = "MacShell (Quickshell desktop shell)";
          PartOf = [ "graphical-session.target" ];
          # After plasma-core.target, as Plasma asks of its session's services (KWin and the environment are up by then),
          # and after plasmashell, so a coexisting plasmashell owns its notification / OSD names first. Never after
          # graphical-session.target: plasma-workspace.target wants this unit and is itself ordered before that target,
          # so systemd found an ordering cycle and dropped MacShell's start job at login.
          After = [ "plasma-core.target" "plasma-plasmashell.service" ];
          # gives up after 3 failures in a minute (instead of restarting forever), then the fallback brings plasmashell back
          StartLimitIntervalSec = 60;
          StartLimitBurst = 3;
          OnFailure = [ "macshell-fallback.service" ];
        };
        Service = {
          ExecStart = "${cfg.package}/bin/macshell";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install = lib.mkIf cfg.autostart { WantedBy = [ "plasma-workspace.target" ]; };
      };

      # MacShell has failed for good: never leave the session without a shell. A no-op while plasmashell already runs.
      systemd.user.services.macshell-fallback = {
        Unit = {
          Description = "Start plasmashell again after MacShell failed";
          # only in a running session: not when MacShell dies because the session is being logged out. After=, so a
          # failure during login waits for the session to finish starting instead of finding the target not yet active
          Requisite = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = [
            "${systemctl} --user unset-environment MACSHELL_KDE_MODE"
            "${systemctl} --user start --no-block plasma-plasmashell.service"
          ];
        };
      };
    }

    (lib.mkIf cfg.lockScreen {
      xdg.dataFile."plasma/shells/com.macshell.lock".source = "${lockPackage}/share/plasma/shells/com.macshell.lock";
      # read by kscreenlocker's greeter, which KWin starts: it has to be in the session's environment at login
      systemd.user.sessionVariables.PLASMA_DEFAULT_SHELL = "com.macshell.lock";
    })

    (lib.mkIf (cfg.autostart && cfg.mode == "replace") {
      # read by the drop-in below, by macshell.service (replace mode) and by `macshell-session status`
      systemd.user.sessionVariables.MACSHELL_KDE_MODE = "replace";

      xdg.configFile."systemd/user/plasma-plasmashell.service.d/macshell.conf".text = ''
        # programs.macshell.mode = "replace": MacShell takes plasmashell's place at login. For the current login,
        # `macshell-session coexist` (or stop) unsets MACSHELL_KDE_MODE and starts plasmashell again.
        [Unit]
        ConditionEnvironment=!MACSHELL_KDE_MODE=replace
      '';
    })
  ]);
}
