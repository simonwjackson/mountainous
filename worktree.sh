git clone --bare git@github.com:Popspots/frontend.git .bare
echo "gitdir: ./.bare" > .git
git worktree add main
