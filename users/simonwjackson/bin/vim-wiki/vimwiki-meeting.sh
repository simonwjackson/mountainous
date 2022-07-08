date="$(date "+%Y-%m-%d_%H-")$(echo "$(date "+%M") - ($(date +%M)%15)" | bc)"
wiki="${HOME}/documents/notes"
wiki_path="meetings/${date}"
file="${wiki}/${wiki_path}.md"
doc=$(cat <<EOF
## ${date}  👥 Topic
tags:: #calendar/meeting👥 
dates:: ${date}
people:: \`[[FirstName LastName]]\`


### Topics


### Agenda



### Notepad



### Action items
- [ ] 
EOF
)

tee () { 
  mkdir -p "${1%/*}" \
  && command tee "$@" > /dev/null;
}

[[ ! -f "${file}" ]] && \
  echo "${doc}" \
  | tee "${file}"

nvim  +'VimwikiIndex' +"VimwikiGoto ${wiki_path}" +'Goyo' -c 'nnoremap <M-x> :xa!<CR>'
