# Github PRs Notifier

This application is a simple NixOS service that periodically fetches the number of open Github pull requests (PRs) that are awaiting review for a specific user. The service runs every 5 minutes and stores the count in a cache file.

## Dependencies

- NixOS 23.05 (Stoat) or later
- zsh shell
- curl
- jq
- coreutils

## Configuration

To configure the service, you need to set the following environment variables:

- `GITHUB_TOKEN`: Your Github personal access token with the `repo` scope.
- `GITHUB_USER`: Your Github username.

## Usage

Once the service is enabled and started, it will run every 5 minutes and store the count of open PRs awaiting your review in a cache file located at `${XDG_CACHE_HOME}/github/open-prs`.

You can read the contents of this file to get the current count of open PRs.

## Customization

If you want to change the frequency of the service, you can modify the `OnBootSec` and `OnUnitActiveSec` values in the `systemd.user.timers."get-open-prs"` section of the Nix configuration file.

## License

This project is released under the MIT License.
