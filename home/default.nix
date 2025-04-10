{
  # Default home-manager configuration for all systems
  
  pkgs, 
  config, 
  lib, 
  ...
}:

{
  # Enable home-manager
  programs.home-manager.enable = true;
  
  # Default packages for all users
  home.packages = with pkgs; [
    htop
    git
    ripgrep
    fd
    curl
    wget
  ];
  
  # Default Git configuration
  programs.git = {
    enable = true;
    userName = "Default User";
    userEmail = "user@example.com";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };
  
  # Default shell configuration - using zsh
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    autocd = true;
    
    shellAliases = {
      ll = "ls -la";
      update = "sudo nixos-rebuild switch";
    };
  };
  
  # This method allows for merging with system-specific configurations
  lib.mkForce = false;
}