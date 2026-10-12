# Admitted production placement. Keep this profile after the three runtime layers.
{ ... }:
{
  nixos.modules.media-placement-unzen =
    { lib, ... }:
    {
      mountainous.features = {
        media-applications = {
          enable = true;
          mediaGid = 390;
          processing = lib.mkDefault "enabled";
          placement = lib.mkDefault {
            sonarr = "unzen";
            radarr = "unzen";
            prowlarr = "unzen";
            nzbget = "unzen";
            transmission = "unzen";
          };
        };
        media-runtime = {
          enable = true;
          libraryMover.enable = true;
        };
        media-identities.enable = true;
      };
    };
}
