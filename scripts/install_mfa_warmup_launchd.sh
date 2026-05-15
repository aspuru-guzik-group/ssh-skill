#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  printf 'This installer is for macOS launchd only.\n' >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
warmup_script="$script_dir/mfa_warmup.sh"
label="org.aspuru-guzik.ssh-skill.mfa-warmup"
plist_dir="$HOME/Library/LaunchAgents"
plist="$plist_dir/${label}.plist"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ssh-skill"
clusters="${SSH_SKILL_MFA_CLUSTERS:-narval cedar killarney}"
attempt_seconds="${SSH_SKILL_MFA_ATTEMPT_SECONDS:-90}"
stagger_seconds="${SSH_SKILL_MFA_STAGGER_SECONDS:-8}"

run_now=0
if [ "${1:-}" = "--run-now" ]; then
  run_now=1
fi

xml_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g'
}

mkdir -p "$plist_dir" "$state_dir"

cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(xml_escape "$warmup_script")</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>SSH_SKILL_MFA_CLUSTERS</key>
    <string>$(xml_escape "$clusters")</string>
    <key>SSH_SKILL_MFA_ATTEMPT_SECONDS</key>
    <string>$(xml_escape "$attempt_seconds")</string>
    <key>SSH_SKILL_MFA_STAGGER_SECONDS</key>
    <string>$(xml_escape "$stagger_seconds")</string>
  </dict>

  <key>StartCalendarInterval</key>
  <array>
    <dict>
      <key>Hour</key>
      <integer>9</integer>
      <key>Minute</key>
      <integer>0</integer>
    </dict>
    <dict>
      <key>Hour</key>
      <integer>19</integer>
      <key>Minute</key>
      <integer>0</integer>
    </dict>
  </array>

  <key>StandardOutPath</key>
  <string>$(xml_escape "$state_dir/mfa-warmup.launchd.out.log")</string>
  <key>StandardErrorPath</key>
  <string>$(xml_escape "$state_dir/mfa-warmup.launchd.err.log")</string>
</dict>
</plist>
EOF

chmod 644 "$plist"

uid="$(id -u)"
launchctl bootout "gui/${uid}" "$plist" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${uid}" "$plist"
launchctl enable "gui/${uid}/${label}" >/dev/null 2>&1 || true

printf 'Installed launchd MFA warmup job: %s\n' "$plist"
printf 'Schedule: daily at 09:00 and 19:00 local time\n'
printf 'Clusters: %s\n' "$clusters"
printf 'Log: %s\n' "$state_dir/mfa-warmup.log"

if [ "$run_now" -eq 1 ]; then
  launchctl kickstart -k "gui/${uid}/${label}"
  printf 'Started one warmup run now.\n'
fi
