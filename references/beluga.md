# Beluga Reference

Use this for `/ssh beluga ...`.

## Access

```bash
ssh beluga
```

Alias:

```text
HostName beluga.computecanada.ca
User from SSH_SKILL_ALLIANCE_USER
IdentityFile from SSH_SKILL_KEY
```

Local SSH config can reuse an approved login through ControlMaster/ControlPersist, but it does not bypass Duo or MFA.

## Monitoring Requirement

If job submission is available, follow `references/monitoring.md` after every `sbatch`: monitor until the job is pending with a clear reason or running, then check CPU/GPU/memory utilization. Flag jobs that reserve GPUs, CPU cores, or memory without using them.

## Status

Beluga is in end-of-service/decommissioning. Public Alliance status says the Beluga compute service stopped with the Rorqual deployment and is not planned to return. Treat Beluga primarily as a data migration or cleanup target unless live checks prove job submission is available.

## Accounts

Known Aspuru-Guzik group Alliance accounts:

```text
rrg-aspuru  # RRG/RAC allocation
def-aspuru  # default/opportunistic allocation
aip-aspuru  # PAICE AI allocation; verify before use
```

Because Beluga compute is stopped/decommissioning, do not plan new jobs around these accounts here. If a Slurm command unexpectedly works, verify the account first:

```bash
ssh beluga 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | grep -E \"^(rrg-aspuru|def-aspuru|aip-aspuru)(_|\\||$)\" || sshare -U $USER || true"'
```

Before doing any real work:

```bash
ssh beluga 'bash -lc "hostname; whoami; pwd; date"'
ssh beluga 'bash -lc "sinfo -o \"%P %a %l %D %G\" 2>/dev/null | head -80 || true"'
ssh beluga 'bash -lc "squeue -u $USER 2>/dev/null || true"'
ssh beluga 'bash -lc "df -h \"$HOME\" \"${SCRATCH:-$HOME}\" \"${PROJECT:-$HOME}\" 2>/dev/null || true"'
```

## Storage

Historical Beluga storage:

```text
$HOME     home directory, historically 50 GB default
$SCRATCH  short-term scratch, historically 20 TB default, not backed up
$PROJECT  group project storage, historically 1 TB default
$NEARLINE nearline/archive storage, if allocated
```

Current decommissioning means quotas and writable paths may be restricted. Verify live before writing. If the request is about data rescue, prefer copying from Beluga to another active cluster or local storage.

## Slurm

Beluga historically had CPU and GPU resources, but current status indicates compute is not returning. Do not assume `sbatch` will work.

If the user explicitly asks to submit on Beluga, first run:

```bash
ssh beluga 'bash -lc "command -v sbatch squeue sinfo sacct 2>/dev/null || true"'
ssh beluga 'bash -lc "sinfo -o \"%P %a %l %D %G\" 2>/dev/null | head -80 || true"'
```

Only submit if Slurm is available and the cluster accepts jobs. Otherwise report that Beluga is not usable for new compute and suggest Narval, Cedar, Killarney, or another active Alliance system.

## Internet

Beluga compute nodes historically blocked internet by default. Because compute is in decommissioning, do not design new network-dependent jobs for Beluga.
