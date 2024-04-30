<h3 align="center">
    <img src="./.github/assets/mountainous-logo.jpg" width="250px"/>
</h3>
<h1 align="center">
    Mountainous | <a href="https://nixos.org">NixOS</a> flake built with <a href="https://github.com/snowfallorg/lib">Snowfall</a> ⚜️
</h1>

<div align="center">
    <img alt="Static Badge" src="https://img.shields.io/badge/NixOS-unstable-d2a8ff?style=for-the-badge&logo=NixOS&logoColor=cba6f7&labelColor=161B22">
    <img alt="Static Badge" src="https://img.shields.io/badge/State-Forever_WIP-ff7b72?style=for-the-badge&logo=fireship&logoColor=ff7b72&labelColor=161B22">
    <img alt="Static Badge" src="https://img.shields.io/badge/Powered_by-Endless_nights-79c0ff?style=for-the-badge&logo=nuke&logoColor=79c0ff&labelColor=161B22">
</div>

## Overview

Here's a quick and incomplete tour of what is going on in the repository:</p>

| Directory   | Purpose                                                                                                                              |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `modules/`  | Stores **NixOS** and **Home-manager** modules. These are the main building block: Every `system` receives the options these declare. |
| `systems/`  | Stores **NixOS** system configurations. These are also often called `hosts`                                                          |
| `homes/`    | Stores **Home-manager** configurations, which are associated with a `system`                                                         |
| `lib/`      | A shared library of functions and variables, available everywhere in the flake at `lib.mountainous.*`                                |
| `packages/` | Packages I could not find in [`nixpkgs`](https://github.com/nixos/nixpkgs), and packaged myself for use in this flake.               |
| `shells/`   | **Nix** shells for bootstrapping, etc.                                                                                               |

Others are not as important. [Snowfall Guide/Reference](https://snowfall.org/guides/lib/quickstart/)
