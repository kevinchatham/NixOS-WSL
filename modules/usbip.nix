{ config, lib, pkgs, ... }:

with lib;

let
  usbipd-win-auto-attach = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dorssel/usbipd-win/v3.1.0/Usbipd/wsl-scripts/auto-attach.sh";
    hash = "sha256-KJ0tEuY+hDJbBQtJj8nSNk17FHqdpDWTpy9/DLqUFaM=";
  };

  cfg = config.wsl.usbip;
in
{
  options.wsl.usbip = with types; {
    enable = mkEnableOption "USB/IP integration";
    autoAttach = mkOption {
      type = listOf str;
      default = [ ];
      example = [ "4-1" ];
      description = "Auto attach devices with provided Bus IDs.";
    };
  };

  config = mkIf (config.wsl.enable && cfg.enable) {
    environment.systemPackages = [
      pkgs.linuxPackages.usbip
    ];

    services.udev.enable = true;

    systemd = {
      services."usbip-auto-attach@" = {
        description = "Auto attach device having busid %i with usbip";
        after = [ "network.target" ];

        scriptArgs = "%i";
        path = with pkgs; [
          iproute2
          linuxPackages.usbip
        ];

        script = ''
          busid="$1"
          ip="$(ip route list | sed -nE 's/(default)? via (.*) dev eth0 proto kernel/\2/p')"

          echo "Starting auto attach for busid $busid on $ip."
          source ${usbipd-win-auto-attach} "$ip" "$busid"
        '';
      };

      targets.multi-user.wants = map (busid: "usbip-auto-attach@${busid}.service") cfg.autoAttach;
    };
  };
}
