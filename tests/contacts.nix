# Prove the guard rejects broken contracts, using the real placement config.
{ lib, self }:
let
  contract = import ../lib/contacts-contract.nix { inherit lib; };
  inherit (self.nixosConfigurations) rakku;
  c = rakku.config;
  check =
    patch:
    contract {
      rakku.config = lib.recursiveUpdate c patch;
    } != [ ];
  sc = patch: check { systemd.services.contacts.serviceConfig = patch; };
in
assert contract { inherit rakku; } == [ ];
assert check { mountainous.features.contacts.listen = "0.0.0.0:8480"; };
assert sc {
  ExecStart = "${lib.getExe c.mountainous.features.contacts.package} serve --listen 0.0.0.0:8480";
};
assert sc { LoadCredential = [ ]; };
assert sc { StateDirectory = "elsewhere"; };
assert sc { StateDirectoryMode = "0755"; };
assert sc { User = "root"; };
assert check { sops.secrets.contacts-password.mode = "0444"; };
assert check { environment.persistence."/tundra/permafrost".directories = [ ]; };
assert check { mountainous.tailnetNames.contacts.backend = "http://0.0.0.0:8480"; };
assert check { systemd.services."contacts@" = c.systemd.services.contacts; };
assert
  contract {
    inherit rakku;
    another = rakku;
  } != [ ];
true
