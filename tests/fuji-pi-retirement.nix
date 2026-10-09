# Run: nix eval --impure --json --file tests/fuji-pi-retirement.nix
let
  flake = builtins.getFlake (toString ../.);
  fuji = flake.nixosConfigurations.fuji.config;
  zao = flake.nixosConfigurations.zao.config;
  # Existing Fuji shares, excluding only the retired Pi share.
  otherFujiFolders = ["biometrics" "fitness" "flakey" "nutrition" "omi" "research" "tasks" "therapy" "transcripts"];
in
  assert fuji.mountainous.features.pi.enable == false;
  assert fuji.programs.pi.coding-agent.enable == false;
  assert !(fuji.services.syncthing.settings.folders ? pi-config);
  assert builtins.attrNames fuji.services.syncthing.settings.folders == otherFujiFolders;
  assert fuji.home-manager.users.simonwjackson.programs.lazygit.settings.customCommands == [];
  assert (fuji.home-manager.users.simonwjackson.programs.lazygit.settings.keybinding.files.commitChanges or "c") == "c";
  assert zao.mountainous.features.pi.enable;
  assert !zao.services.syncthing.enable;
  assert builtins.any (command: command.key == "c") zao.home-manager.users.simonwjackson.programs.lazygit.settings.customCommands; {
    fujiPiDisabled = true;
    fujiPiSyncRemoved = true;
    otherFujiFoldersPreserved = true;
    zaoPiPreserved = true;
    zaoSyncthingDisabled = true;
  }
