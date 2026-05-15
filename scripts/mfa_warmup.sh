#!/usr/bin/env bash
set -u

env_file="${XDG_CONFIG_HOME:-$HOME/.config}/ssh-skill/env"
if [ -f "$env_file" ]; then
  # shellcheck disable=SC1090
  . "$env_file"
fi

clusters="${SSH_SKILL_MFA_CLUSTERS:-beluga narval cedar killarney}"
attempt_seconds="${SSH_SKILL_MFA_ATTEMPT_SECONDS:-90}"
push_response="${SSH_SKILL_MFA_RESPONSE:-1}"
stagger_seconds="${SSH_SKILL_MFA_STAGGER_SECONDS:-8}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ssh-skill"
log_file="$state_dir/mfa-warmup.log"

mkdir -p "$state_dir"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" | tee -a "$log_file"
}

compact_file() {
  tr '\n' ' ' < "$1" | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//'
}

control_is_active() {
  ssh -O check "$1" >/dev/null 2>&1
}

warm_one() {
  cluster="$1"
  out_file="$(mktemp)"

  if control_is_active "$cluster"; then
    log "$cluster: control connection already active"
    rm -f "$out_file"
    return 0
  fi

  log "$cluster: starting MFA warmup"
  (
    printf '%s\n' "$push_response"
    sleep 2
    printf '%s\n' "$push_response"
  ) | ssh \
    -o BatchMode=no \
    -o PreferredAuthentications=publickey,keyboard-interactive \
    -o PubkeyAuthentication=yes \
    -o KbdInteractiveAuthentication=yes \
    -o NumberOfPasswordPrompts=1 \
    -o ConnectionAttempts=1 \
    -o ConnectTimeout=20 \
    "$cluster" 'hostname; whoami' >"$out_file" 2>&1 &

  ssh_pid=$!
  elapsed=0
  while kill -0 "$ssh_pid" >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$attempt_seconds" ]; then
      kill "$ssh_pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$ssh_pid" >/dev/null 2>&1 || true
      log "$cluster: timed out after ${attempt_seconds}s; $(compact_file "$out_file")"
      rm -f "$out_file"
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$ssh_pid"
  status=$?
  output="$(compact_file "$out_file")"
  rm -f "$out_file"

  if [ "$status" -eq 0 ]; then
    log "$cluster: warmup ok; ${output}"
  else
    log "$cluster: warmup failed status=${status}; ${output}"
  fi
  return "$status"
}

log "mfa warmup begin; clusters=${clusters}"
overall=0
first=1
for cluster in $clusters; do
  if [ "$first" -eq 0 ] && [ "$stagger_seconds" -gt 0 ]; then
    sleep "$stagger_seconds"
  fi
  first=0
  warm_one "$cluster" || overall=1
done
log "mfa warmup end; status=${overall}"
exit "$overall"
