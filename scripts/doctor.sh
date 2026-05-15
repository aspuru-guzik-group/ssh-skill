#!/usr/bin/env bash
set -euo pipefail

env_file="${XDG_CONFIG_HOME:-$HOME/.config}/ssh-skill/env"
if [ -f "$env_file" ]; then
  # shellcheck disable=SC1090
  . "$env_file"
fi

clusters="mariana comte niagara beluga narval cedar killarney"

printf 'SSH skill environment:\n'
printf '  SSH_SKILL_ALLIANCE_USER=%s\n' "${SSH_SKILL_ALLIANCE_USER:-<unset>}"
printf '  SSH_SKILL_MATTER_USER=%s\n' "${SSH_SKILL_MATTER_USER:-<unset>}"
printf '  SSH_SKILL_KEY=%s\n' "${SSH_SKILL_KEY:-<unset>}"

for cluster in $clusters; do
  printf '\n[%s]\n' "$cluster"
  out_file="$(mktemp)"
  err_file="$(mktemp)"
  if ! ssh -G "$cluster" >"$out_file" 2>"$err_file"; then
    cat "$err_file"
    rm -f "$out_file" "$err_file"
    continue
  fi
  awk '/^(hostname|user|identityfile|controlmaster|controlpersist|stricthostkeychecking) /{print "  " $0}' "$out_file"
  rm -f "$out_file" "$err_file"
done

printf '\nFor a non-interactive auth check after first Duo login:\n'
printf "%s\n" "  ssh -o BatchMode=yes narval 'hostname; whoami'"
