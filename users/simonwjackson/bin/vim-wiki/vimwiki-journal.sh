date=$(date '+%Y-%m-%d')
wiki="${HOME}/documents/notes"
wiki_path="journal/${date}"
file="${wiki}/${wiki_path}.md"
doc=$(cat <<EOF
tags:: #calendar
dates:: ${date}

# ${date}

## Log
*  


## Jots
* 

---

## Wind Down
- Accomplishments 
  - 
- Interactions
  - 
- Regrets
  - 
- Enjoyments 
  - 
EOF
)

tee () { 
  mkdir -p "${1%/*}" \
  && command tee "$@" > /dev/null;
}

# File does not exist OR file is empty
if [[ ! -f "${file}" ]] || [[ ! -s "${file}" ]]; then
  echo "${doc}" | tee "${file}"
fi

nvim  +'VimwikiIndex' +"VimwikiGoto ${wiki_path}" +'Goyo' -c 'nnoremap <M-x> :xa!<CR>'
