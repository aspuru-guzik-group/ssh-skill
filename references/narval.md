# Narval Reference

Use this for `/ssh narval ...`.

## Access

```bash
ssh narval
```

Alias:

```text
HostName narval.computecanada.ca
User from SSH_SKILL_ALLIANCE_USER
IdentityFile from SSH_SKILL_KEY
```

Local SSH config can reuse an approved login through ControlMaster/ControlPersist, but it does not bypass Duo or MFA.

## Monitoring Requirement

After every `sbatch` submission, follow `references/monitoring.md`: monitor until the job is pending with a clear reason or running, then check CPU/GPU/memory utilization. Flag jobs that reserve A100 GPUs, CPU cores, or memory without using them.

## First Commands

```bash
ssh narval 'bash -lc "hostname; whoami; pwd; date"'
ssh narval 'bash -lc "printf \"HOME=%s\nSCRATCH=%s\nPROJECT=%s\nSLURM_TMPDIR=%s\n\" \"$HOME\" \"${SCRATCH:-}\" \"${PROJECT:-}\" \"${SLURM_TMPDIR:-}\""'
ssh narval 'bash -lc "sinfo -o \"%P %a %l %D %G\" | head -80"'
ssh narval 'bash -lc "squeue -u $USER"'
ssh narval 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | sort -u || sshare -U $USER || true"'
ssh narval 'bash -lc "diskusage_report 2>/dev/null || quota -s 2>/dev/null || true"'
```

## Accounts

Live discovery on 2026-05-15 confirmed these Narval Slurm account patterns for an Aspuru-Guzik group user:

```text
rrg-aspuru_cpu  # RRG/RAC CPU account; prefer for normal CPU research jobs
rrg-aspuru_gpu  # RRG/RAC GPU account; prefer for normal GPU research jobs
def-aspuru_cpu  # default/opportunistic CPU account
def-aspuru_gpu  # default/opportunistic GPU account
```

`aip-aspuru` nearline storage exists, but no `aip-aspuru` Slurm account was visible on Narval during discovery. Do not submit with `aip-aspuru` on Narval unless live discovery later shows it.

Verify before submission:

```bash
ssh narval 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | grep -E \"^(rrg-aspuru|def-aspuru|aip-aspuru)(_|\\||$)\" || sshare -U $USER || true"'
```

## Storage

Use variables and discover exact paths:

```text
$HOME          /home/$USER; code, configs, small files
$SCRATCH       /scratch/$USER; active job directories, logs, processed data
$PROJECT       empty in this shell; use project symlinks instead
$HOME/projects project-allocation symlinks
$SLURM_TMPDIR  fast per-job local scratch on compute nodes; cleared after each job
```

Live project symlinks on 2026-05-15:

```text
$HOME/projects/def-aspuru
$HOME/projects/rrg-aspuru
```

Live quota snapshot on 2026-05-15:

```text
/home/$USER             50 GB space, 500K files
/scratch/$USER          20 TB space, 1000K files
/project/def-aspuru     1000 GB space, 500K files
/project/rrg-aspuru     50 TB space, 500K files
/nearline/def-aspuru    1000 GB space, 5000 files
/nearline/rrg-aspuru    1000 GB space, 5000 files
/nearline/aip-aspuru    1000 GB space, 5000 files
```

For I/O-heavy jobs, copy inputs to `$SLURM_TMPDIR` at job start, run there, and copy results back to `$SCRATCH` or a project symlink such as `$HOME/projects/rrg-aspuru`.

## Slurm

Narval has CPU and A100 GPU partitions. Use the `_cpu` accounts for CPU jobs and `_gpu` accounts for GPU jobs.

Partition families visible on 2026-05-15:

```text
cpubase_interac     8:00:00
cpubase_bycore_b1   3:00:00
cpubase_bycore_b2   12:00:00
cpubase_bycore_b3   1-00:00:00
cpubase_bycore_b4   3-00:00:00
cpubase_bycore_b5   7-00:00:00
cpubase_bynode_b1   3:00:00
cpubase_bynode_b2   12:00:00
cpubase_bynode_b3   1-00:00:00
cpubase_bynode_b4   3-00:00:00
cpubase_bynode_b5   7-00:00:00
gpubase_interac     8:00:00
gpubase_bygpu_b1    3:00:00
gpubase_bygpu_b2    12:00:00
gpubase_bygpu_b3    1-00:00:00
gpubase_bygpu_b4    3-00:00:00
gpubase_bygpu_b5    7-00:00:00
gpubackfill         1-00:00:00
cpubackfill         1-00:00:00
```

GPU resources include full A100 GPUs and A100 MIG slices such as `a100_4g.20gb`, `a100_3g.20gb`, `a100_2g.10gb`, and `a100_1g.5gb`. Prefer full A100 with `--gres=gpu:a100:1` unless the user asks for MIG.

CPU template:

```bash
#!/bin/bash
#SBATCH --job-name=narval_cpu
#SBATCH --account=rrg-aspuru_cpu
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
#SBATCH --job-name=narval_gpu
#SBATCH --account=rrg-aspuru_gpu
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --gres=gpu:a100:1
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
ssh narval 'bash -lc "sinfo -o \"%P %G %D\" | head -80"'
```

## Modules

Live module discovery on 2026-05-15:

```text
httpproxy/1.0
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

Treat Narval compute nodes as no-internet by default. For tools such as Comet or W&B, some environments support:

```bash
module load httpproxy
```

Verify before relying on it. Prefer offline logging and staged dependencies.
