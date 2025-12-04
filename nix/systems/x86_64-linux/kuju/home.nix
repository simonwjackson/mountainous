{
  config,
  pkgs,
  lib,
  ...
}: {
  # ============================================================================
  # HOME-MANAGER CONFIGURATION - kuju (GPD G1617-02 Gaming Handheld)
  # ============================================================================
  #
  # System-specific home-manager configuration for kuju portable gaming device.
  # Add any kuju-specific packages, keybindings, or settings here.
  #
  # The gaming.home configuration in default.nix handles most gaming-specific
  # home-manager settings (Steam, Moonlight, keybindings, etc.)
  #
  # ============================================================================

  # Gaming handheld specific packages
  home.packages = with pkgs; [
    # Add handheld-specific tools here if needed
    # e.g., TDP control utilities, custom launchers, etc.
  ];

  # Future: Add kuju-specific Hyprland/gaming configurations here
}
