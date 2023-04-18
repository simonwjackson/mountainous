[alias]
    clone-bare = "!f() { git clone --bare \"$1\" .bare && echo \"gitdir: ./.bare\" > .git && git config --add remote.origin.fetch \"+refs/heads/*:refs/remotes/origin/*\" && git worktree add main; }; f"
