## Options section
setopt correct                                                  # Auto correct mistakes
setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
setopt nocaseglob                                               # Case insensitive globbing
setopt rcexpandparam                                            # Array expension with parameters
setopt nocheckjobs                                              # Don't warn about running processes when exiting
setopt numericglobsort                                          # Sort filenames numerically when it makes sense
setopt nobeep                                                   # No beep
setopt appendhistory                                            # Immediately append history instead of overwriting
setopt histignorealldups                                        # If a new command is a duplicate, remove the older one
setopt autocd                                                   # if only directory path is entered, cd there.

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' rehash true                              # automatically find new executables in path 
# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache


# INFO: Needed for non nix pip packages
export PATH="${HOME}/.local/bin:${PATH}"
# INFO: Needed for non nix ruby packages
export PATH=$(ruby=("${HOME}/.local/share/gem/ruby/**/bin"); printf "%s:" "${ruby[@]}" | sed 's/.$//'):${PATH}
# INFO: Needed for Flatpack
export PATH="/var/lib/flatpak/exports/share:${HOME}/.local/bin:${HOME}/.local/share/flatpak/exports/share:${PATH}"

WORDCHARS=${WORDCHARS//\/[&.;]}                                 # Don't consider certain characters part of the word

autoload edit-command-line; zle -N edit-command-line

# Function section 

__fzfcmd() {
  [ -n "$TMUX_PANE" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "$FZF_TMUX_OPTS" ]; } &&
    echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-40%}} -- " || echo "fzf"
}

CommandHistory () {
    output=$(cat ${HISTFILE} \
      | fzf +s --tac --header="return: exec, ctrl-e: edit, left: edit, right: edit" --expect=return,ctrl-e,left,right \
    )
    type=$(echo "${output}" | head -n 1)
    command=$(echo "${output}" | awk 'NR>1')

    case $type in
        "ctrl-e")
          BUFFER="$command"
          edit-command-line
          zle accept-line
        ;;
        "return")
          BUFFER="$command"
          zle accept-line
        ;;
        "left")
          BUFFER="$command"
          zle beginning-of-line
        ;;
        "right")
          BUFFER="$command"
          zle end-of-line
        ;;
    esac
}

# paru install
paru-install () {
  paru -Slq \
  | fzf \
    --query "${@}" \
    --multi \
    --preview 'paru -Si {1}' \
    --preview-window=top \
  | xargs -ro paru -S
}



fzf-history-widget () {
  print -z $(
    ([ -n "$ZSH_NAME" ] && fc -l 1 || history) \
    | fzf +s --tac --height "50%" \
    | sed -E 's/ *[0-9]*\*? *//' \
    | sed -E 's/\\/\\\\/g'
  )
}

fzf-cd-widget() {
  the_path=${@}

  if [ $# -eq 0 ]; then
    the_path=$(pwd)
  fi

  dir=$(
    fd --type d '' "${the_path}" \
    | fzf \
    | xargs -L 1 zsh -c 'echo "${the_path}/$0"'
  )

  cd "${dir}"
}

fzf-file-widget() {
  the_path=${@}

  if [ $# -eq 0 ]; then
    the_path=$(pwd)
  fi

  fd --type f --hidden '' "${the_path}" \
  | fzf
}

fzf-file-edit-widget() {
  fzf-file-widget "${@}" | xargs $EDITOR
}

# VIM is less
# less () {
#   vim -u ~/.config/nvim/less.vimrc -
# }

just-play () {
  socket=/tmp/mpv.socket 

  killall mpv

  youtube-dl "ytsearch100:${@}" \
    -j \
    --flat-playlist \
    --skip-download \
  | jq --raw-output '.id' \
  | sed 's_^_https://youtu.be/_' \
  | mpv \
      --input-ipc-server="${socket}" \
      --ytdl-raw-options=format=bestaudio \
      --shuffle \
      --playlist=- &
}

function take {
  command mkdir -p $1 && cd $1
}

# Theming section  
autoload -U compinit colors zcalc
compinit -d
colors

# Dotfiles
# TODO: Rewrite with zsh-autoenv
function dots () {
  export GIT_DIR="${HOME}/dotfiles" 
  export GIT_WORK_TREE="${HOME}" 

  if [[ $# -eq 0 ]]; then
    git status
  elif [[ "${1}" == "edit" ]]; then
    nvim -c "lcd ${HOME} | Lf" "${HOME}"
  else
    git $@
  fi

  unset GIT_DIR
  unset GIT_WORK_TREE
}

function git-here () {
  [[ "${PWD}" = ~ ]] && lazygit --git-dir ~/dotfiles --work-tree ~ || lazygit
}

# PROMPT=$([[ -n $IN_NIX_SHELL ]] && echo "❄ | $PROMPT")
