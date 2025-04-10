{
  # System-specific home-manager configuration for vmware
  
  pkgs, 
  config, 
  lib, 
  ...
}:

{
  # Override username and email for this specific system
  programs.git = {
    userName = "VMware User";
    userEmail = "vmware-user@example.com";
  };
  
  # Add system-specific packages
  home.packages = with pkgs; [
    # VM-specific tools
    virt-manager
    spice-gtk
    
    # Development tools for this system
    vscode
    nodejs
  ];
  
  # System-specific shell configuration
  programs.zsh.shellAliases = {
    # Add VM-specific aliases
    vm-start = "virsh start default";
    vm-stop = "virsh shutdown default";
  };
}