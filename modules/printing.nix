# A CUPS print server, so a physically tethered printer can be shared.
#
# The printer this exists for is a Brother HL-L2300D on a USB cable. A USB
# printer is bound to whichever machine it is plugged into, which makes that
# machine a dependency of every other machine wanting to print. Moving the
# service onto an always-on host turns a tethered device into a network one.
#
# `services.printing.ensurePrinters` does not exist in this nixpkgs revision,
# so the queue is created by an idempotent oneshot unit instead: `lpadmin`
# modifies an existing queue with the same name rather than failing.
#
# Avahi publishes the queue over mDNS, which is what lets macOS, Windows and
# other Linux hosts discover it without being told an address.
{
  nixos.modules.printing =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.printing;
      inherit (lib) mkEnableOption mkOption types mkIf;
    in
    {
      options.mountainous.printing = {
        enable = mkEnableOption "a shared CUPS print server";

        queueName = mkOption {
          type = types.str;
          default = "Office_Printer";
          description = "CUPS queue name. Also the name other machines see.";
        };

        deviceUri = mkOption {
          type = types.str;
          example = "usb://Brother/HL-L2300D%20series?serial=U63878A0N138131";
          description = ''
            The CUPS device URI.

            For a USB printer this carries the unit's serial number, so it
            names one physical printer rather than one USB port. The queue
            therefore follows the printer between ports and machines.
          '';
        };

        model = mkOption {
          type = types.str;
          default = "drv:///brlaser.drv/brl2300d.ppd";
          description = "CUPS model/PPD identifier for the queue.";
        };

        description = mkOption {
          type = types.str;
          default = "Office Printer";
        };

        location = mkOption {
          type = types.str;
          default = "Office";
        };

        drivers = mkOption {
          type = types.listOf types.package;
          default = [ pkgs.brlaser ];
          description = "CUPS driver packages. brlaser covers Brother lasers.";
        };
      };

      config = mkIf cfg.enable {
        services.printing = {
          enable = true;
          inherit (cfg) drivers;
          # Reachable from the LAN, not just this machine: the point of
          # moving the service here is that other hosts use it.
          listenAddresses = [ "*:631" ];
          allowFrom = [ "all" ];
          browsing = true;
          defaultShared = true;
          openFirewall = true;
        };

        # Declarative queue creation. lpadmin is idempotent, so this runs on
        # every boot and changes nothing once the queue is correct.
        systemd.services."ensure-${cfg.queueName}-queue" = {
          description = "Ensure the ${cfg.queueName} CUPS queue exists";
          after = [ "cups.service" ];
          requires = [ "cups.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [ pkgs.cups ];
          script = ''
            # cupsd accepts the socket before it is ready to serve. Wait for
            # it to answer rather than racing the first lpadmin.
            for _ in $(seq 1 30); do
              if lpstat -r >/dev/null 2>&1; then break; fi
              sleep 1
            done

            lpadmin -p '${cfg.queueName}' -E \
              -v '${cfg.deviceUri}' \
              -m '${cfg.model}' \
              -D '${cfg.description}' \
              -L '${cfg.location}' \
              -o printer-is-shared=true
            lpadmin -d '${cfg.queueName}'
          '';
        };

        # mDNS publication, so peers discover the queue automatically.
        services.avahi = {
          enable = true;
          nssmdns4 = true;
          nssmdns6 = true;
          openFirewall = true;
          publish = {
            enable = true;
            userServices = true;
          };
        };
      };
    };
}