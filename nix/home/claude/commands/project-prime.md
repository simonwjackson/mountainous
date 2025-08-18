# Context Prime
> Follow the instructions to understand the context of the project.

<prime>
## Run the following commands

```sh
nix run nixpkgs#eza -- --tree --all --git-ignore 2>/dev/null
```

## Read high level project files
> Read any matching files below that exist in this project. Focus on files that provide project context, configuration, and structure. Prioritize files in the root directory first.

Examples:

```
# Core project documentation
@docs/**/*.md

# Project configuration
project.json
package.json
flake.nix
default.nix
*.conf
*.config.js
*.config.ts
```
</prime>

<output_requirements>
- Do not provide any response, confirmation, or content summary after reading the file.
- This command is solely to load the file information for future reference in our conversation.
- Proceed silently after completing this task.
</output_requirements>
