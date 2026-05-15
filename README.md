# Aspuru-Guzik SSH Skill

Agent skill for operating Aspuru-Guzik group and Alliance Canada clusters over SSH.

Supported aliases:

```text
mariana
comte
niagara
beluga
narval
cedar
killarney
```

## Install

Install or copy this skill into your agent's skills directory, then run the one-time setup:

```bash
bash scripts/install_ssh_config.sh
```

The setup asks for:

- Alliance/CCDB username for Narval, Cedar, Killarney, Beluga, and Niagara.
- Matter/CSLab username for Mariana and Comte.
- SSH key path, or it creates `~/.ssh/id_ed25519` if no key exists.

It writes:

```text
~/.config/ssh-skill/env
~/.ssh/config.d/aspuru-guzik-clusters
```

and ensures `~/.ssh/config` includes `~/.ssh/config.d/*`.

## CCDB Setup

The installer prints your public SSH key. Add that key to CCDB, then confirm:

- MFA/Duo is enrolled.
- Required cluster agreements are accepted.
- Your role/renewal is active.
- Your group allocations are visible.

After CCDB updates, access can take time to propagate.

## First Login

Run an interactive login once per cluster so Duo can be approved and SSH connection reuse can start:

```bash
ssh narval
ssh killarney
```

After a successful Duo login, repeated agent commands usually reuse the SSH control socket for several hours.

## Usage

From an agent:

```text
/ssh narval show my jobs
/ssh killarney submit this GPU job
/ssh mariana check ORCA output
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
references/mariana.md
references/comte.md
references/niagara.md
references/beluga.md
references/narval.md
references/cedar.md
references/killarney.md
```
