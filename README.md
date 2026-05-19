# Matterlab SSH Skill

Agent skill for operating Matterlab and Alliance Canada clusters over SSH.

Supported aliases:

```text
mariana
comte
narval
cedar
killarney
trillium
```

## Install With npx

Install the `/ssh` skill:

```bash
npx skills add aspuru-guzik-group/ssh-skill
```

Then run the one-time SSH setup from the installed skill directory:

```bash
bash ~/.codex/skills/ssh/scripts/install_ssh_config.sh
```

If your agent uses a custom skill directory, install to that directory explicitly:

```bash
npx skills add aspuru-guzik-group/ssh-skill --target ~/.agent/skills/ssh
```

The package also supports direct invocation from this repository package:

```bash
npx --yes --package git+ssh://git@github.com/aspuru-guzik-group/ssh-skill.git skills add aspuru-guzik-group/ssh-skill
```

## One-Time Agent Onboarding

Agents installing this skill for a new user should walk through this once per user and machine:

1. Ask for the user's Alliance/CCDB username for Narval, Cedar, Killarney, and Trillium.
2. Ask for the user's Matter/CSLab username for Mariana and Comte, if they use those clusters.
3. Confirm whether the default Mariana/Comte hostnames and Aspuru-Guzik Slurm accounts should be used.
4. Ask whether to use an existing SSH key or create one. Never ask for or copy a private key.
5. Run the setup script from the installed skill directory:

```bash
bash scripts/install_ssh_config.sh
```

6. Give the user the printed public key and ask them to add it to their CCDB SSH keys / authorized keys page.
7. Ask the user to confirm in CCDB that MFA/Duo is enrolled, cluster agreements are accepted, their role is active, and the needed group allocations are visible.
8. After CCDB propagation, run first interactive logins so the user can approve Duo:

```bash
ssh narval
ssh killarney
ssh trillium
```

9. Verify the aliases with:

```bash
bash scripts/doctor.sh
ssh narval 'hostname; whoami'
```

10. On macOS agent machines that should stay ready for Slack/agent use, optionally install the scheduled MFA warmup:

```bash
bash scripts/install_mfa_warmup_launchd.sh
```

Per-user values are stored only in `~/.config/ssh-skill/env`; do not commit usernames, keys, tokens, passwords, or personal paths to this repository.

## Manual Install

Install or copy this skill into your agent's skills directory, then run the one-time setup:

```bash
bash scripts/install_ssh_config.sh
```

The setup asks for:

- Alliance/CCDB username for Narval, Cedar, Killarney, and Trillium.
- Matter/CSLab username for Mariana and Comte.
- Mariana/Comte hostnames, prefilled with lab defaults.
- Aspuru-Guzik Slurm account names, prefilled with lab defaults.
- SSH key path from `SSH_SKILL_KEY`, or an existing local key; it creates `~/.ssh/id_ed25519` if no key exists.

It writes:

```text
~/.config/ssh-skill/env
~/.ssh/config.d/aspuru-guzik-clusters
```

and ensures `~/.ssh/config` includes `~/.ssh/config.d/*`.

The repository stores shared Matterlab cluster metadata and Aspuru-Guzik allocation names. It must not store personal usernames, public keys, private keys, tokens, passwords, MFA state, or personal filesystem paths. Per-user values are written only to the local env file above.

## Agent Integration

For OpenClaw, copy this repository into the relevant workspace skill directory, for example:

```bash
rsync -a --delete --exclude='.git/' ./ ~/.openclaw/workspace-slack-shared/skills/ssh/
```

For Hermes, copy this repository into a category under `~/.hermes/skills`, for example:

```bash
mkdir -p ~/.hermes/skills/devops/ssh
rsync -a --delete --exclude='.git/' ./ ~/.hermes/skills/devops/ssh/
```

The skill includes trigger phrases for `/ssh`, cluster-specific SSH/submission requests, and ORCA quantum chemistry jobs.

## CCDB Setup

The installer prints your public SSH key. Add that key to CCDB, then confirm:

- MFA/Duo is enrolled.
- Required cluster agreements are accepted.
- Your role/renewal is active.
- Your group allocations are visible.

After CCDB updates, access can take time to propagate.

## Public Repo Safety

Before publishing a fork or release, check the tracked files:

```bash
git grep -n -I -E 'BEGIN .*KEY|PRIVATE KEY|password|passcode|token|secret|SSH_SKILL_ALLIANCE_USER=.*[^<]|SSH_SKILL_MATTER_USER=.*[^<]' -- .
git grep -n -I -E '/Users/[A-Za-z0-9._-]+|/home/[^$<{[:space:]]+|/scratch/[^$<{[:space:]]+' -- .
```

These checks should not return real user accounts, keys, tokens, or personal paths.


## First Login

Run an interactive login once per cluster, or use the MFA helper, so Duo can be approved and SSH connection reuse can start:

```bash
ssh narval
ssh killarney
ssh trillium
bash scripts/mfa_warmup.sh trillium
```

After a successful Duo login, repeated agent commands usually reuse the SSH control socket for several hours.

## GitHub Clones From Clusters

The generated SSH config enables SSH agent forwarding for all cluster aliases. This lets clusters clone private GitHub repositories through your local SSH agent without copying private GitHub keys onto shared cluster storage.

Test from a cluster:

```bash
ssh narval 'ssh -o StrictHostKeyChecking=accept-new -T git@github.com'
```

If this succeeds, private SSH clones work:

```bash
git clone git@github.com:OWNER/REPO.git
```

If GitHub auth still fails after installing this config, close old SSH control sockets and reconnect:

```bash
ssh -O exit narval || true
ssh narval
```

## MFA Helpers

For a single cluster:

```bash
bash scripts/mfa_trillium.sh
SSH_SKILL_MFA_RESPONSE_TRILLIUM=2 bash scripts/mfa_trillium.sh
```

The helper waits for a Duo/passcode prompt and sends the configured menu option. The user still approves Duo. It does not bypass MFA or approve anything automatically.

Each MFA-backed Alliance cluster has a wrapper so prompt matching can be tuned independently:

```text
scripts/mfa_narval.sh
scripts/mfa_cedar.sh
scripts/mfa_killarney.sh
scripts/mfa_trillium.sh
```

## MFA Warmup Schedule

On macOS agent machines, install the scheduled warmup:

```bash
bash scripts/install_mfa_warmup_launchd.sh
```

This runs at 09:00 and 19:00 local time and starts normal SSH authentication for MFA-backed Alliance clusters so the user can approve Duo. It does not bypass MFA or approve anything automatically.

Default warmup targets:

```text
narval cedar killarney trillium
```

To override the list:

```bash
SSH_SKILL_MFA_CLUSTERS="narval cedar killarney trillium" bash scripts/install_mfa_warmup_launchd.sh
```

Logs are written to:

```text
~/.local/state/ssh-skill/mfa-warmup.log
```

## Usage

From an agent:

```text
/ssh narval show my jobs
/ssh killarney submit this GPU job
/ssh trillium submit this GPU job
/ssh mariana check ORCA output
/ssh narval submit this ORCA input
```

Direct shell checks:

```bash
bash scripts/doctor.sh
ssh narval 'hostname; whoami'
```

## Job Monitoring

After every `sbatch`, agents must monitor resource utilization. Use:

```bash
bash scripts/monitor_job.sh <cluster> <jobid>
```

The monitor checks Slurm state plus CPU, GPU, and memory usage. Jobs that request many GPUs/cores/memory while leaving them idle should be flagged and downsized or cancelled with user approval.

## References

Cluster-specific instructions live in `references/`:

```text
references/onboarding.md
references/monitoring.md
references/orca.md
references/mariana.md
references/comte.md
references/narval.md
references/cedar.md
references/killarney.md
references/trillium.md
```
