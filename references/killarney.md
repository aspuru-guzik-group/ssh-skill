# Killarney Reference

Use this for `/ssh killarney ...`.

## Access

```bash
ssh killarney
```

Alias:

```text
HostName killarney.alliancecan.ca
User from SSH_SKILL_ALLIANCE_USER
IdentityFile from SSH_SKILL_KEY
```

Local SSH config can reuse an approved login through ControlMaster/ControlPersist, but it does not bypass Duo or MFA.

## Monitoring Requirement

After every `sbatch` submission, follow `references/monitoring.md`: monitor until the job is pending with a clear reason or running, then check GPU/CPU/memory utilization. Killarney jobs are GPU-focused, so requested L40S/H100 GPUs must show meaningful utilization after warmup.

## Status

Live discovery on 2026-05-15 confirmed Killarney login, Slurm, H100/L40S GPU partitions, and the `aip-aspuru` Slurm account for an Aspuru-Guzik group user. It appears GPU-focused; no CPU-only partition was visible in the first `sinfo` pass.

## First Commands

```bash
ssh killarney 'bash -lc "hostname; whoami; pwd; date"'
ssh killarney 'bash -lc "command -v sbatch squeue sinfo sacct salloc srun 2>/dev/null || true"'
ssh killarney 'bash -lc "printf \"HOME=%s\nSCRATCH=%s\nPROJECT=%s\nSLURM_TMPDIR=%s\nTMPDIR=%s\n\" \"$HOME\" \"${SCRATCH:-}\" \"${PROJECT:-}\" \"${SLURM_TMPDIR:-}\" \"${TMPDIR:-}\""'
ssh killarney 'bash -lc "sinfo -o \"%P %a %l %D %G\" 2>/dev/null | head -100 || true"'
ssh killarney 'bash -lc "squeue -u $USER 2>/dev/null || true"'
ssh killarney 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | sort -u || sshare -U $USER || true"'
ssh killarney 'bash -lc "df -h \"$HOME\" \"${SCRATCH:-$HOME}\" \"${PROJECT:-$HOME}\" 2>/dev/null || true"'
```

## Accounts

Live discovery on 2026-05-15 confirmed this Killarney Slurm account pattern:

```text
aip-aspuru  # QOS: interac, normal
```

`rrg-aspuru` and `def-aspuru` were not visible as Killarney Slurm accounts during discovery. Do not use them on Killarney unless live discovery later shows them.

Verify before submission:

```bash
ssh killarney 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | grep -E \"^(rrg-aspuru|def-aspuru|aip-aspuru)(_|\\||$)\" || sshare -U $USER || true"'
```

## Storage

Live paths from 2026-05-15:

```text
$HOME     /home/$USER
$SCRATCH  /scratch/$USER
$PROJECT  empty in this shell; use project symlink instead
project   $HOME/projects/aip-aspuru
```

Live quota snapshot from 2026-05-15:

```text
/home/$USER              50 GiB space, 500K files
/project/aip-aspuru      5000 GiB space, 25M files
/scratch/$USER           exists, but diskusage_report could not retrieve quota
```

Use `$SCRATCH` for active job directories and `$HOME/projects/aip-aspuru` for persistent project data/results. Use `$SLURM_TMPDIR` inside jobs if Slurm sets it, then copy results back before the job exits.

## Hardware

Live Slurm discovery on 2026-05-15 showed Killarney as a GPU-only system:

```text
L40S nodes:
167 nodes x 64 CPUs, 515000 MB RAM, 4 x NVIDIA L40S
1 node    x 128 CPUs, 515000 MB RAM, 4 x NVIDIA L40S

H100 nodes:
9 nodes   x 48 CPUs, 2060000 MB RAM, 8 x NVIDIA H100
1 node    x 96 CPUs, 2060000 MB RAM, 8 x NVIDIA H100
```

Approximate physical GPU inventory from live Slurm node data: 168 L40S nodes / 672 L40S GPUs, and 10 H100 nodes / 80 H100 GPUs. No CPU-only partitions were visible during discovery.

## Slurm

Use `#SBATCH --account=aip-aspuru`.

Visible partitions on 2026-05-15:

```text
gpubase_h100_b1    3:00:00     gpu:h100:8
gpubase_h100_b2    12:00:00    gpu:h100:8
gpubase_h100_b3    1-00:00:00  gpu:h100:8
gpubase_h100_b4    3-00:00:00  gpu:h100:8
gpubase_h100_b5    7-00:00:00  gpu:h100:8
gpubase_interac    3:00:00     gpu:l40s:4
gpubase_l40s_b1    3:00:00     gpu:l40s:4
gpubase_l40s_b2    12:00:00    gpu:l40s:4
gpubase_l40s_b3    1-00:00:00  gpu:l40s:4
gpubase_l40s_b4    3-00:00:00  gpu:l40s:4
gpubase_l40s_b5    7-00:00:00  gpu:l40s:4
```

For most GPU jobs, prefer L40S unless the user specifically needs H100. Start with one GPU unless the workflow uses more.

Generic L40S GPU template:

```bash
#!/bin/bash
#SBATCH --job-name=killarney_gpu
#SBATCH --account=aip-aspuru
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --gres=gpu:l40s:1
#SBATCH --output=%x-%j.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"
module purge
# module load StdEnv/2023 cuda python/3.12

hostname
nvidia-smi || true
# command here
```

H100 job variant:

```text
#SBATCH --gres=gpu:h100:1
```

Interactive test:

```bash
salloc --account=aip-aspuru --qos=interac --time=00:30:00 --cpus-per-task=4 --mem=16G --gres=gpu:l40s:1
```

## Modules

Live module discovery on 2026-05-15:

```text
orca/4.2.1
orca/5.0.1
orca/5.0.2
orca/5.0.3
orca/5.0.4
orca/6.0.0
orca/6.0.1
orca/6.1.0
orca/6.1.1
python/3.12.4
python/3.13.2
python/3.14.2
cuda/12.2
cuda/12.6
cuda/12.9
cuda/13.2
apptainer/1.4.5
```

`module spider gaussian` did not find Gaussian during discovery.

## Internet

Unknown. If a job needs network access, submit a tiny test job first or stage all dependencies/data before submission.
