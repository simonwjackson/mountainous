#!/usr/bin/env bash
# Link reviewed, immutable skill packages into one assistant's private home.
set -euo pipefail
if (( $# == 0 || ($# - 1) % 2 != 0 )); then
  echo 'usage: pi-assistant-skills AGENT_DIR [NAME SOURCE]...' >&2
  exit 2
fi
agent=$1
shift
case "$agent" in /*) ;; *) echo 'Agent directory must be absolute' >&2; exit 2 ;; esac
arguments=("$@")
# Validate every source before changing any link. A local skill directory is
# never removed or replaced; an operator must resolve that conflict first.
while (( $# > 0 )); do
  name=$1 source=$2
  shift 2
  if [[ ! $name =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    echo 'Invalid skill name' >&2
    exit 2
  fi
  case "$source" in /*) ;; *) echo 'Skill source must be absolute' >&2; exit 2 ;; esac
  if [[ ! -f $source/SKILL.md ]]; then
    echo "Skill source is not ready: $name" >&2
    exit 1
  fi
  if [[ -e $agent/skills/$name && ! -L $agent/skills/$name ]]; then
    echo "Refuse to replace local skill: $name" >&2
    exit 1
  fi
done
mkdir -p "$agent/skills"
set -- "${arguments[@]}"
while (( $# > 0 )); do
  name=$1 source=$2
  shift 2
  ln -sfnT "$source" "$agent/skills/$name"
done
