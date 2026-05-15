# Niagara Reference

Use this for `/ssh niagara ...`.

## Access

```bash
ssh niagara
```

Alias:

```text
HostName niagara.computecanada.ca
User from SSH_SKILL_ALLIANCE_USER
IdentityFile from SSH_SKILL_KEY
```

Local SSH config can reuse an approved login through ControlMaster/ControlPersist, but it does not bypass Duo or MFA.

## Monitoring Requirement

If job submission is available, follow `references/monitoring.md` after every `sbatch`: monitor until the job is pending with a clear reason or running, then check CPU/GPU/memory utilization. Flag jobs that reserve nodes, cores, or memory without using them.

## Status

Niagara is legacy. Public SciNet docs say Niagara was decommissioned on 2025-09-30. Do not use it for new jobs unless the user explicitly asks. If reachable, treat it as legacy/data-migration only until verified.

## Accounts

Known Aspuru-Guzik group Alliance accounts:

```text
rrg-aspuru
def-aspuru
aip-aspuru
```

Because Niagara is decommissioned, do not plan new jobs around these accounts here. If login still works for migration, verify any Slurm association before use:

```bash
ssh niagara 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | grep -E \"^(rrg-aspuru|def-aspuru|aip-aspuru)(_|\\||$)\" || sshare -U $USER || true"'
```

Before doing anything:

```bash
ssh niagara 'bash -lc "hostname; whoami; pwd; date"'
ssh niagara 'bash -lc "sinfo -o \"%P %a %l %D %G\" 2>/dev/null | head -80 || true"'
ssh niagara 'bash -lc "squeue -u $USER 2>/dev/null || true"'
```

## Storage

Legacy Niagara paths are group-qualified. Use variables rather than hard-coded paths:

```text
$HOME     /home/<group-initial>/<group>/<user>
$SCRATCH  /scratch/<group-initial>/<group>/<user>
$PROJECT  /project/<group-initial>/<group>/<user>
$ARCHIVE  /archive/<group-initial>/<group>/<user>, if allocated
$BBUFFER  burst-buffer space, if present
```

Important Niagara-specific rules:

- `$HOME` is read-only on compute nodes.
- Submit jobs from `$SCRATCH` when possible.
- Write job output to `$SCRATCH` or `$PROJECT`, not `$HOME`.
- Compute nodes have no internet access.

## Slurm

Niagara scheduled jobs by whole node. Legacy docs describe:

```text
40 cores per node
compute partition for normal jobs
debug partition for short troubleshooting jobs
24 hour max walltime for normal compute jobs
```

Accounts are allocation-specific. Most single-account users historically did not need to specify one, but if multiple accounts are available use `#SBATCH --account=ACCOUNT` or `sbatch --account=ACCOUNT job.sh`.

Discover before submitting:

```bash
ssh niagara 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | sort -u || sshare -U $USER || true"'
```

Legacy CPU template:

```bash
#!/bin/bash
#SBATCH --job-name=niagara_job
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=40
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

module purge
# module load NiaEnv/2019b

hostname
# command here
```

Do not submit this until Niagara login and Slurm availability are verified.
