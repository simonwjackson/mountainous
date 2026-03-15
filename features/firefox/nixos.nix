{
  config,
  lib,
  cascade,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.firefox;

  cascadeUserChrome = ''
    @import url("file://${cascade}/chrome/includes/cascade-config.css");
    @import url("file://${cascade}/chrome/includes/cascade-colours.css");

    @import url("file://${cascade}/chrome/includes/cascade-layout.css");
    @import url("file://${cascade}/chrome/includes/cascade-responsive.css");
    @import url("file://${cascade}/chrome/includes/cascade-floating-panel.css");

    @import url("file://${cascade}/chrome/includes/cascade-nav-bar.css");
    @import url("file://${cascade}/chrome/includes/cascade-tabs.css");

    @media (prefers-color-scheme: dark) {
      :root {
        --uc-identity-colour-blue: #7aa2f7;
        --uc-identity-colour-turquoise: #2ac3de;
        --uc-identity-colour-green: #9ece6a;
        --uc-identity-colour-yellow: #e0af68;
        --uc-identity-colour-orange: #ff9e64;
        --uc-identity-colour-red: #f7768e;
        --uc-identity-colour-pink: #ff75a0;
        --uc-identity-colour-purple: #bb9af7;

        --uc-base-colour: #1a1b26;
        --uc-highlight-colour: #24283b;
        --uc-inverted-colour: #c0caf5;
        --uc-muted-colour: #565f89;
        --uc-accent-colour: #7aa2f7;
      }
    }

    @media (prefers-color-scheme: light) {
      :root {
        --uc-identity-colour-blue: #2e7de9;
        --uc-identity-colour-turquoise: #007197;
        --uc-identity-colour-green: #587539;
        --uc-identity-colour-yellow: #8c6c3e;
        --uc-identity-colour-orange: #b15c00;
        --uc-identity-colour-red: #8c4351;
        --uc-identity-colour-pink: #c64343;
        --uc-identity-colour-purple: #7847bd;

        --uc-base-colour: #e1e2e7;
        --uc-highlight-colour: #d5d6db;
        --uc-inverted-colour: #3760bf;
        --uc-muted-colour: #848cb5;
        --uc-accent-colour: #2e7de9;
      }
    }
  '';
in {
  config = mkIf (cfg.enable && cfg.cascade.enable) {
    mountainous.features.firefox.userChrome = mkDefault cascadeUserChrome;
  };
}
