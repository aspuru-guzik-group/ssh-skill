#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SSH_SKILL_MFA_PROMPT_REGEX_KILLARNEY="${SSH_SKILL_MFA_PROMPT_REGEX_KILLARNEY:-passcode or option|duo passcode|verification code|token code|one[- ]?time password|otp|enter[^\r\n]*passcode[^\r\n]*:}"
exec "$script_dir/mfa_warmup.sh" killarney "$@"
