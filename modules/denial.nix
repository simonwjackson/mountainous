{ inputs, ... }:
{
  nixos.modules.denial =
    { pkgs, config, ... }:
    let
      session = pkgs.writeShellScript "denial-phone-session" ''
        export DENIAL_SHELL_PROFILE=mobile
        export LD_LIBRARY_PATH=${pkgs.vulkan-loader}/lib
        exec ${config.programs.denial.package}/bin/denial-session
      '';
    in
    {
      imports = [ inputs.denial.nixosModules.default ];
      programs.denial.enable = true;
      hardware.graphics.enable = true;
      users.users.simon.extraGroups = [
        "input"
        "render"
      ];
      services.greetd = {
        enable = true;
        settings = {
          initial_session = {
            user = "simon";
            command = "${session}";
          };
          default_session = {
            user = "greeter";
            command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${session}";
          };
        };
      };
    };
}
