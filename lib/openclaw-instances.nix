# Rehearse the exact Laure definition on another name. At handoff, change only
# legacy.enable: her real state, node, profile role and address remain in place.
{ legacyEnabled }:
let
  people = import ./openclaw-people.nix;
  instances = people // {
    laure =
      people.laure
      // (
        if legacyEnabled then
          {
            containerName = "claw-laure";
            nodeName = "claw-laure";
          }
        else
          { }
      );
  };
in
{
  simon = instances.simon // {
    peerNodeName = instances.laure.nodeName;
  };
  laure = instances.laure // {
    peerNodeName = instances.simon.nodeName;
  };
}
