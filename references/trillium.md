# Trillium Reference

Use this for `/ssh trillium ...`.

## Access

Default GPU login alias:

```bash
ssh trillium
```

Alias:

```text
HostName trillium-gpu.scinet.utoronto.ca
User from SSH_SKILL_ALLIANCE_USER
IdentityFile from SSH_SKILL_KEY
```

Trillium also has a CPU login host, `trillium.scinet.utoronto.ca`. The skill's `trillium` alias intentionally targets the GPU login host so GPU jobs can be prepared and submitted from the right environment.

Local SSH config can reuse an approved login through ControlMaster/ControlPersist, but it does not bypass Duo or MFA.

## Monitoring Requirement

After every `sbatch` submission, follow `references/monitoring.md`: monitor until the job is pending with a clear reason or running, then check CPU, GPU, and memory utilization. GPU jobs must show meaningful utilization on the requested GPUs after warmup.

## First Commands

Run these after the first Duo-approved login:

```bash
ssh trillium 'bash -lc "hostname; whoami; pwd; date"'
ssh trillium 'bash -lc "command -v sbatch squeue sinfo sacct salloc srun 2>/dev/null || true"'
ssh trillium 'bash -lc "printf \"HOME=%s\nSCRATCH=%s\nPROJECT=%s\nSLURM_TMPDIR=%s\nTMPDIR=%s\n\" \"$HOME\" \"${SCRATCH:-}\" \"${PROJECT:-}\" \"${SLURM_TMPDIR:-}\" \"${TMPDIR:-}\""'
ssh trillium 'bash -lc "sinfo -o \"%P %a %l %D %G %C\" 2>/dev/null | head -120 || true"'
ssh trillium 'bash -lc "squeue -u $USER 2>/dev/null || true"'
ssh trillium 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | sort -u || sshare -U $USER || true"'
ssh trillium 'bash -lc "df -h \"$HOME\" \"${SCRATCH:-$HOME}\" \"${PROJECT:-$HOME}\" 2>/dev/null || true"'
ssh trillium 'bash -lc "module avail 2>&1 | grep -Ei \"cuda|python|pytorch|apptainer|gcc|cmake\" | head -120 || true"'
```

## Accounts

Do not assume Trillium accepts the same exact Slurm account names as Narval, Cedar, or Killarney. Verify live before submission:

```bash
ssh trillium 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | grep -E \"^(rrg-aspuru|def-aspuru|aip-aspuru)(_|\\||$)\" || sshare -U $USER || true"'
```

Use the verified account in `#SBATCH --account=<account>`.

## Storage

Discover live paths first; Trillium/SciNet path names can differ from other Alliance clusters.

Prefer scratch or project storage for active datasets, generated shards, checkpoints, and logs. Keep `$HOME` for code and small config files only. If `$SCRATCH` or `$PROJECT` is unset, inspect mounted filesystems and project symlinks before writing large files.

## Slurm

Trillium uses Slurm. Discover partitions and GPU names before writing final job scripts:

```bash
ssh trillium 'bash -lc "sinfo -o \"%P %a %l %D %G %C\" | head -120"'
ssh trillium 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 | sort -u"'
```

Generic GPU template after live partition/account discovery:

```bash
#!/bin/bash
#SBATCH --job-name=trillium_gpu
#SBATCH --account=<verified-account>
#SBATCH --partition=<verified-gpu-partition>
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gres=<verified-gpu-gres>
#SBATCH --output=%x-%j.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"
module purge
# module load cuda python

hostname
nvidia-smi || true
# command here
```

For large generated datasets, submit a small shard first, measure rows/sec and storage footprint, then scale with a Slurm array. Do not launch a 1M-sample HotKnots/Knotty generation without a measured shard estimate.

## Internet

Unknown for compute nodes. Stage repositories, Python wheels, Hugging Face data, and source tarballs from the login node before jobs, or submit a tiny connectivity test job first.
