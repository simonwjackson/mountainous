date=$(date '+%Y-w%U')
wiki="${HOME}/documents/notes"
wiki_path="journal/${date}"
file="${wiki}/${wiki_path}.md"
doc=$(cat <<EOF
tags:: #calendar
dates:: ${date}

# ${date}

## Goals (1-2, small but significant)

----

## Accomplishments

  * 

## Highs

  * 

## Struggles

  *

## Learned

  *

## Improve

  *

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
