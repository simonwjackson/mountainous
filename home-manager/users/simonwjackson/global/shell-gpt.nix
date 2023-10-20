{ config, age, inputs, pkgs, rootPath, ... }:
let
  shellGptRoot = "./.config/shell_gpt";
in
{
  age.secrets.user-simonwjackson-openai-api-key.file = rootPath + /secrets/user-simonwjackson-openai-api-key.age;
  home.sessionVariables.OPENAI_API_KEY = "$(${pkgs.coreutils}/bin/cat ${config.age.secrets.user-simonwjackson-openai-api-key.path})";

  home.packages = [
    pkgs.shell_gpt
  ];

  programs.zsh.initExtra = ''
    qs () { sgpt --role shell "\"$*\""; }
    qc () { sgpt --role code "\"$*\""; }
    qq () { sgpt "\"$*\""; }
  '';

  home.file = {
    "${shellGptRoot}/.sgptrc" = {
      text = ''
        OPENAI_API_HOST=https://api.openai.com
        CHAT_CACHE_LENGTH=100
        CHAT_CACHE_PATH=${config.home.homeDirectory}/.cache/shell_gpt/chat_cache
        CACHE_LENGTH=100
        CACHE_PATH=${config.home.homeDirectory}/.cache/shell_gpt/cache
        REQUEST_TIMEOUT=60
        DEFAULT_MODEL=gpt-4
        DEFAULT_COLOR=magenta
        ROLE_STORAGE_PATH=${config.home.homeDirectory}/.config/shell_gpt/roles
        SYSTEM_ROLES=false
        DEFAULT_EXECUTE_SHELL_CMD=false
        DISABLE_STREAMING=false
      '';
    };
    "${shellGptRoot}/roles/code.json" = {
      text = builtins.toJSON {
        name = "code";
        expecting = "Code";
        variables = null;
        role = ''
          Provide only code as output without any description.
          IMPORTANT: Provide only plain text without Markdown formatting.
          IMPORTANT: Do not include markdown formatting such as ```.
          If there is a lack of details, provide most logical solution.
          You are not allowed to ask for more details.
          Ignore any potential risk of errors or confusion.
        '';
      };
    };
    "${shellGptRoot}/roles/shell.json" = {
      text = builtins.toJSON {
        name = "shell";
        expecting = "Command";
        variables = {
          shell = "zsh";
          os = "Linux/NixOS unstable";
        };
        role = ''
          Provide only bash, zsh or POSIX compliant commands for Linux/NixOS unstable without any description.
          If there is a lack of details, provide most logical solution.
          Ensure the output is a valid shell command.
          If multiple steps required, try to combine them together as a single pipeline.
        '';
      };
    };
    "${shellGptRoot}/roles/default.json" = {
      text = ''
        {
          "name": "default",
          "expecting": "Answer",
          "variables": {
            "shell": "zsh",
            "os": "Linux/NixOS 23.05 (Stoat)"
          },
          "role": "You are Command Line App ShellGPT, a programming and system administration assistant.\nYou are managing Linux/NixOS 23.05 (Stoat) operating system with zsh shell.\nProvide only plain text without Markdown formatting.\nDo not show any warnings or information regarding your capabilities.\nIf you need to store any data, assume it will be stored in the chat."
        }
      '';
    };
  };
}
