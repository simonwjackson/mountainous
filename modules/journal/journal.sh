if [ "$#" -ne 1 ]; then
  echo "Usage: $0 log [new log entry]"
  exit 1
fi

currentTime=$(date +%R)
currentDate=$(date +%F)
journalFile="/home/simonwjackson/documents/notes/journal/${currentDate}.md"

if [ ! -f "$journalFile" ]; then
  touch "$journalFile"
fi

# Check if file starts with date
if ! grep --quiet --perl-regexp --only-matching --null-data "${currentDate}\n==========" "$journalFile"; then
  tempJournal=$(mktemp)
  echo -e "${currentDate}\n==========" | cat "$journalFile" - >"$tempJournal" && mv "$tempJournal" "$journalFile"
fi

function to_atx_markdown() {
  pandoc \
    --from=markdown \
    --to=markdown \
    --wrap=none
}

function to_setext_markdown() {
  awk '{
    if ($0 ~ /^# /) {
        gsub(/^# /,"");
        len = length($0);
        print;
        for (i = 1; i <= len; i++)
            printf("=");
        printf("\n");
    } else if ($0 ~ /^## /) {
        gsub(/^## /,"");
        len = length($0);
        print;
        for (i = 1; i <= len; i++)
            printf("-");
        printf("\n");
    } else {
        print;
    }
  }'
}

function extract_section() {
  section=$1

  awk -v section="$section" '
    $0 ~ "^## " section {
       flag = 1
       next
    }
    $0 ~ /^#/ && flag {
       flag = 0
       next
    }
    flag {
       print
    }
  ' | grep '\- '
}

function sort_log() {
  sort -k2,2 -k3,3n
}

function replace_section() {
  section=$1
  with=$2

  cat "$journalFile" |
    to_atx_markdown |
    awk -v with="$with" -v section="$section" '
    $0 ~ "^## " section {
       print $0 "\n"
       print with
       flag = 1
       next
    }
    $0 ~ /^#/ && flag {
       print "\n" $0
       flag = 0
       next
    }
    !flag {
       print
       next
    }
    END {
       if (flag) {
         printf "\n"
       }
    }
  '
}

case "$1" in
"task")
  echo -n "❯ "
  read -r newTask

  if ! grep --quiet --perl-regexp --only-matching --null-data "tasks\n-----" "$journalFile"; then
    echo -e "\ntasks\n-----\n" | tee -a "$journalFile" /dev/null 2>&1
  fi

  tempJournal=$(mktemp)

  newTasks=$(
    cat "$journalFile" |
      to_atx_markdown |
      extract_section tasks |
      {
        cat
        echo -e "-   ${newTask}"
      }
  )

  replace_section tasks "$newTasks" | to_setext_markdown >"$tempJournal" &&
    mv "$tempJournal" "$journalFile"

  ;;
"log")
  echo -n "❯ "
  read -r newLog

  if ! grep --quiet --perl-regexp --only-matching --null-data "log\n---" "$journalFile"; then
    echo -e "\nlog\n---\n" | tee -a "$journalFile" /dev/null 2>&1
  fi

  tempJournal=$(mktemp)

  newLogs=$(
    cat "$journalFile" |
      to_atx_markdown |
      extract_section log |
      {
        cat
        echo -e "-   ${currentTime} - ${newLog}"
      } |
      sort_log
  )

  replace_section log "$newLogs" | to_setext_markdown >"$tempJournal" &&
    mv "$tempJournal" "$journalFile"

  ;;
*) ;;
esac
