git clone --bare git@github.com:Popspots/frontend.git .bare
echo "gitdir: ./.bare" > .git
git config --add remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git worktree add main
