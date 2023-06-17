#!/bin/sh

# List tmux sessions
sessions=$(tmux list-sessions -F "#{session_name}")

# Function to generate a tmux session preview
generate_preview() {
  local session_name="$1"
  tmux capture-pane -t "${session_name}" -p -S -"${LINES}"
}

# Use fzf to interactively select a session and show a preview
selected_session=$(echo "$sessions" | fzf --preview 'bash -c "generate_preview {}"')

# Attach to the selected session if one was chosen
if [ -n "$selected_session" ]; then
  tmux switch-client -n "$selected_session"
fi

