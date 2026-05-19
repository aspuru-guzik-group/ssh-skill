#!/usr/bin/env bash
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="${XDG_CONFIG_HOME:-$HOME/.config}/ssh-skill/env"
if [ -f "$env_file" ]; then
  # shellcheck disable=SC1090
  . "$env_file"
fi

default_clusters="${SSH_SKILL_MFA_CLUSTERS:-narval cedar killarney trillium}"
attempt_seconds="${SSH_SKILL_MFA_ATTEMPT_SECONDS:-90}"
default_response="${SSH_SKILL_MFA_RESPONSE:-1}"
stagger_seconds="${SSH_SKILL_MFA_STAGGER_SECONDS:-8}"
command="${SSH_SKILL_MFA_COMMAND:-hostname; whoami}"
default_prompt_regex="${SSH_SKILL_MFA_PROMPT_REGEX:-passcode or option|duo passcode|verification code|token code|one[- ]?time password|otp|enter[^\r\n]*passcode[^\r\n]*:}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ssh-skill"
log_file="$state_dir/mfa-warmup.log"
expect_helper="$script_dir/mfa_ssh.expect"
force=0
dry_run=0
clusters=""

mkdir -p "$state_dir"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [cluster ...]

Start a normal SSH login to MFA-backed clusters so the user can approve Duo.
The helper waits for a Duo/passcode prompt before sending the configured menu
option or passcode. It never approves, bypasses, stores, or simulates MFA.

Options:
  --response VALUE   Duo menu option or passcode to send. Default: SSH_SKILL_MFA_RESPONSE or 1.
  --timeout SECONDS  Maximum time to wait per cluster. Default: $attempt_seconds.
  --stagger SECONDS  Delay between clusters. Default: $stagger_seconds.
  --no-stagger       Do not delay between clusters.
  --force            Start auth even if an SSH control connection is already active.
  --dry-run          Print selected clusters without connecting.
  -h, --help         Show this help.

Per-cluster response and prompt regex overrides are supported, for example:
  SSH_SKILL_MFA_RESPONSE_TRILLIUM=2 $(basename "$0") trillium
  SSH_SKILL_MFA_PROMPT_REGEX_TRILLIUM='passcode or option|verification code' $(basename "$0") trillium

Default clusters: $default_clusters
EOF
}

append_cluster() {
  if [ -z "$clusters" ]; then
    clusters="$1"
  else
    clusters="$clusters $1"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --response)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --response\n' >&2
        exit 2
      fi
      default_response="$1"
      ;;
    --response=*)
      default_response="${1#*=}"
      ;;
    --timeout)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --timeout\n' >&2
        exit 2
      fi
      attempt_seconds="$1"
      ;;
    --timeout=*)
      attempt_seconds="${1#*=}"
      ;;
    --stagger)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --stagger\n' >&2
        exit 2
      fi
      stagger_seconds="$1"
      ;;
    --stagger=*)
      stagger_seconds="${1#*=}"
      ;;
    --no-stagger)
      stagger_seconds=0
      ;;
    --force)
      force=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        append_cluster "$1"
        shift
      done
      break
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      append_cluster "$1"
      ;;
  esac
  shift
done

if [ -z "$clusters" ]; then
  clusters="$default_clusters"
fi

case "$attempt_seconds" in
  ''|*[!0-9]*)
    printf 'Invalid --timeout value: %s\n' "$attempt_seconds" >&2
    exit 2
    ;;
esac

case "$stagger_seconds" in
  ''|*[!0-9]*)
    printf 'Invalid --stagger value: %s\n' "$stagger_seconds" >&2
    exit 2
    ;;
esac

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" | tee -a "$log_file"
}

compact_file() {
  tr '\n' ' ' < "$1" | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//'
}

control_is_active() {
  ssh -O check "$1" >/dev/null 2>&1
}

cluster_env_value() {
  prefix="$1"
  cluster="$2"
  fallback="$3"
  normalized="$(printf '%s' "$cluster" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')"
  var_name="${prefix}_${normalized}"
  value="${!var_name-}"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

run_with_pipe_fallback() {
  cluster="$1"
  response="$2"
  (
    sleep 1
    printf '%s\n' "$response"
    sleep 2
    printf '%s\n' "$response"
  ) | ssh \
    -o BatchMode=no \
    -o PreferredAuthentications=publickey,keyboard-interactive \
    -o PubkeyAuthentication=yes \
    -o KbdInteractiveAuthentication=yes \
    -o NumberOfPasswordPrompts=1 \
    -o ConnectionAttempts=1 \
    -o ConnectTimeout=20 \
    "$cluster" "$command"
}

run_mfa_ssh() {
  cluster="$1"
  response="$2"
  prompt_regex="$3"

  if command -v expect >/dev/null 2>&1 && [ -x "$expect_helper" ]; then
    SSH_SKILL_MFA_CLUSTER="$cluster" \
      SSH_SKILL_MFA_RESPONSE="$response" \
      SSH_SKILL_MFA_TIMEOUT="$attempt_seconds" \
      SSH_SKILL_MFA_COMMAND="$command" \
      SSH_SKILL_MFA_PROMPT_REGEX="$prompt_regex" \
      "$expect_helper"
  else
    printf 'mfa: expect is unavailable; falling back to timed stdin response\n' >&2
    run_with_pipe_fallback "$cluster" "$response"
  fi
}

warm_one() {
  cluster="$1"
  out_file="$(mktemp)"
  response="$(cluster_env_value SSH_SKILL_MFA_RESPONSE "$cluster" "$default_response")"
  prompt_regex="$(cluster_env_value SSH_SKILL_MFA_PROMPT_REGEX "$cluster" "$default_prompt_regex")"

  if [ "$dry_run" -eq 1 ]; then
    log "$cluster: dry-run; would wait for MFA prompt and send configured response"
    rm -f "$out_file"
    return 0
  fi

  if [ "$force" -eq 0 ] && control_is_active "$cluster"; then
    log "$cluster: control connection already active"
    rm -f "$out_file"
    return 0
  fi

  log "$cluster: starting MFA warmup"
  run_mfa_ssh "$cluster" "$response" "$prompt_regex" >"$out_file" 2>&1 &

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
