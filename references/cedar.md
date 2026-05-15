# Cedar Reference

Use this for `/ssh cedar ...`.

## Access

```bash
ssh cedar
```

Alias:

```text
HostName cedar.computecanada.ca
User from SSH_SKILL_ALLIANCE_USER
IdentityFile from SSH_SKILL_KEY
```

Local SSH config can reuse an approved login through ControlMaster/ControlPersist, but it does not bypass Duo or MFA.

## Monitoring Requirement

After every `sbatch` submission, follow `references/monitoring.md`: monitor until the job is pending with a clear reason or running, then check CPU/GPU/memory utilization. Flag jobs that reserve GPUs, CPU cores, or memory without using them.

## First Commands

```bash
ssh cedar 'bash -lc "hostname; whoami; pwd; date"'
ssh cedar 'bash -lc "printf \"HOME=%s\nSCRATCH=%s\nPROJECT=%s\nSLURM_TMPDIR=%s\n\" \"$HOME\" \"${SCRATCH:-}\" \"${PROJECT:-}\" \"${SLURM_TMPDIR:-}\""'
ssh cedar 'bash -lc "sinfo -o \"%P %a %l %D %G\" | head -80"'
ssh cedar 'bash -lc "squeue -u $USER"'
ssh cedar 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | sort -u || sshare -U $USER || true"'
ssh cedar 'bash -lc "diskusage_report 2>/dev/null || quota -s 2>/dev/null || true"'
```

## Accounts

Known Aspuru-Guzik group Alliance accounts:

```text
rrg-aspuru  # RRG/RAC allocation; prefer for normal research jobs if valid on Cedar
def-aspuru  # default/opportunistic allocation; good fallback for small/default jobs
aip-aspuru  # PAICE AI allocation; use only if Cedar Slurm shows it is valid
```

Verify before submission:

```bash
ssh cedar 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | grep -E \"^(rrg-aspuru|def-aspuru|aip-aspuru)(_|\\||$)\" || sshare -U $USER || true"'
```

## Storage

Historical Cedar defaults:

```text
$HOME     home directory, historically 50 GB default
$SCRATCH  short-term scratch, historically 20 TB default, not backed up
$PROJECT  group project storage, historically 1 TB default
$NEARLINE nearline/archive storage, if allocated
```

Use `$SCRATCH` for active job directories and logs, `$PROJECT` for persistent project data/results, and `$SLURM_TMPDIR` for fast per-job local scratch.

Avoid submitting or writing heavy job outputs from `$HOME`; prefer `$SCRATCH`.

## Hardware

Cedar required a fresh Duo session during the 2026-05-15 skill update, so these specs are from public/historical Cedar hardware notes and should be verified live with `sinfo` after login:

```bash
ssh cedar 'bash -lc "sinfo -N -o \"%N %c %m %G %f\" | head -120"'
ssh cedar 'bash -lc "sinfo -o \"%P %D %c %m %G %f\" | sort -u | head -120"'
```

Public/historical Cedar specs:

```text
Total: 101,424 CPU cores, 1,352 GPUs

CPU nodes:
576 nodes  x 32 cores, 125 GB RAM
640 nodes  x 48 cores, 187 GB RAM
768 nodes  x 48 cores, 187 GB RAM

Large-memory CPU nodes:
128 nodes  x 32 cores, 250 GB RAM
24 nodes   x 32 cores, 502 GB RAM
24 nodes   x 32 cores, 1510 GB RAM
4 nodes    x 32 cores, 3022 GB RAM

GPU nodes:
114 nodes  x 24 cores, 125 GB RAM, 4 x NVIDIA P100 12 GB
32 nodes   x 24 cores, 250 GB RAM, 4 x NVIDIA P100 16 GB
192 nodes  x 32 cores, 187 GB RAM, 4 x NVIDIA V100 32 GB with NVLink
```

Common Cedar GPU requests:

```text
#SBATCH --gres=gpu:p100:1
#SBATCH --gres=gpu:p100l:1
#SBATCH --gres=gpu:v100l:1
```

## Slurm

Cedar has CPU, GPU, project storage, nearline storage, and dCache resources in public allocation tables. Use `rrg-aspuru`, `def-aspuru`, or `aip-aspuru` only after live verification shows the account is valid for the requested partition/QOS.

CPU template:

```bash
#!/bin/bash
#SBATCH --job-name=cedar_cpu
#SBATCH --account=ACCOUNT_CHANGEME
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=%x-%j.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"
module purge
# module load StdEnv/2023 python/3.12

hostname
# command here
```

GPU template:

```bash
#!/bin/bash
#SBATCH --job-name=cedar_gpu
#SBATCH --account=ACCOUNT_CHANGEME
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH --output=%x-%j.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"
module purge
# module load StdEnv/2023 cuda python/3.12

nvidia-smi || true
# command here
```

Discover GPU types with:

```bash
ssh cedar 'bash -lc "sinfo -o \"%P %G %D\" | head -80"'
```

## Internet

Cedar has historically allowed compute-node internet by default, but still verify if the job depends on network access. Prefer staged dependencies and offline-safe workflows.
