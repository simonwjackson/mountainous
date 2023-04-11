# Fuzzy Music

Fuzzy Music is a script that exports album data from two beet databases, processes the JSON output, and uses fzf to display and search the albums. The selected album is then played using MPV through a socket.

## Dependencies:

- beet - A music library manager and MediaWiki command line tool
- jq - A lightweight and flexible command-line JSON processor
- fzf - A general-purpose command-line fuzzy finder
- socat - A utility for data transfer between two addresses
- xargs - A utility to build and execute command lines from standard input
- awk - A text processing tool for scanning and processing text
- grep - A command-line utility for searching plain-text data for lines that match a regular expression
- sed - A stream editor used to perform basic text transformations on an input stream (a file or input from a pipeline)
- tr - A command-line utility for translating or deleting characters
- ssh - A secure shell for logging into and executing commands on a remote machine

## Usage:

```
fuzzy-music [options]
```

## Options:

- `-h`, `--help`: Show help message and exit.

## Example:

```
fuzzy-music
```

This script assumes that the remote hosts have `beet` installed. The remote hosts are defined in the `remote_host` variable within the script.
