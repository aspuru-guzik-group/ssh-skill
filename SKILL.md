---
name: ssh
description: Use agents to operate Aspuru-Guzik group and Alliance Canada clusters over SSH. Use when the user invokes /ssh [cluster] <instruction>, needs first-time SSH/CCDB onboarding, or asks to inspect Slurm queues, submit jobs, create job scripts, use scratch/project storage, monitor/cancel jobs, or debug jobs on mariana, comte, niagara, beluga, narval, cedar, or killarney.
version: 1.0.0
user-invocable: true
metadata:
  openclaw:
    requires:
      bins:
        - ssh
  hermes:
    tags:
      - ssh
      - cluster
      - slurm
      - hpc
      - alliance
      - aspuru-guzik
trigger_phrases:
  - /ssh
  - ssh mariana
  - ssh comte
  - ssh niagara
  - ssh beluga
  - ssh narval
  - ssh cedar
  - ssh killarney
  - submit to mariana
  - submit to comte
  - submit to niagara
  - submit to beluga
  - submit to narval
  - submit to cedar
  - submit to killarney
---

# SSH Clusters

Use this skill when the user invokes `/ssh ...` or asks the agent to work on a configured cluster.

Invocation format:

```text
/ssh [cluster] <instruction>
```

Known clusters:

```text
mariana   -> mariana.matter.sandbox       user from SSH_SKILL_MATTER_USER
comte     -> comte.matter.sandbox         user from SSH_SKILL_MATTER_USER
niagara   -> niagara.computecanada.ca     user from SSH_SKILL_ALLIANCE_USER
beluga    -> beluga.computecanada.ca      user from SSH_SKILL_ALLIANCE_USER
narval    -> narval.computecanada.ca      user from SSH_SKILL_ALLIANCE_USER
cedar     -> cedar.computecanada.ca       user from SSH_SKILL_ALLIANCE_USER
killarney -> killarney.alliancecan.ca     user from SSH_SKILL_ALLIANCE_USER
```

If the first word after `/ssh` is not one of these cluster names, default to `mariana` for backward compatibility and treat the whole text as the instruction.

## Onboarding

Before first use on a new machine, read `references/onboarding.md`. If SSH aliases or environment variables are missing, run:

```bash
bash scripts/install_ssh_config.sh
```

The setup stores per-user values in:

```text
~/.config/ssh-skill/env
```

Expected variables:

```text
SSH_SKILL_ALLIANCE_USER  # Alliance/CCDB username, used for Narval/Cedar/Killarney/etc.
SSH_SKILL_MATTER_USER    # local Matter/CSLab username, used for Mariana/Comte
SSH_SKILL_KEY            # private key path, usually ~/.ssh/id_ed25519 or ~/.ssh/id_rsa
```

The setup also writes cluster aliases to `~/.ssh/config.d/aspuru-guzik-clusters` and adds `Include ~/.ssh/config.d/*` to `~/.ssh/config` when needed.

## References

Read the relevant reference before submitting or modifying jobs:

```text
references/onboarding.md # first-time setup and CCDB SSH key checklist
references/monitoring.md # required post-submit CPU/GPU/memory utilization checks
references/mariana.md    # Mariana-specific Slurm/storage/ORCA notes
references/comte.md      # Comte discovery-first notes
references/niagara.md    # Niagara legacy/decommissioned notes
references/beluga.md     # Beluga status/storage/job notes
references/narval.md     # Narval storage/job/network notes
references/cedar.md      # Cedar storage/job/network notes
references/killarney.md  # Killarney H100/L40S GPU notes
```

For simple status checks (`hostname`, `whoami`, `pwd`, `squeue`, `sinfo`, `module avail`, checking a log), you can proceed directly and consult the reference only if needed.

## Connection

Use the local SSH alias for the selected cluster:

```bash
ssh <cluster>
```

For non-interactive commands, prefer:

```bash
ssh <cluster> 'bash -lc "COMMAND HERE"'
```

Use careful quoting. When commands are complex, create a short remote script with a quoted heredoc and then run it.

## Auth Rules

- Do not try to bypass Duo, MFA, passwords, or site access controls.
- SSH keys may remove password prompts, but Alliance systems can still require MFA. If authentication blocks automation, tell the user they need to approve the first login or install the public key through CCDB.
- The generated SSH config uses ControlMaster/ControlPersist, so repeated commands can reuse a previously authenticated connection for several hours.
- If a cluster says the public key is not accepted, ask the user to add their public key from `scripts/install_ssh_config.sh` to CCDB or the cluster's supported authorized-keys page, then retry.
- Do not copy private GitHub keys onto shared clusters. The generated SSH config uses `ForwardAgent yes` so private GitHub repositories can be cloned through the user's local SSH agent while the cluster session is active.
- If GitHub access fails after enabling agent forwarding, close any old SSH control connection and reconnect: `ssh -O exit <cluster> || true`, then test with `ssh <cluster> 'ssh -T git@github.com'`.

## GitHub Access From Clusters

Private GitHub clones should use SSH URLs:

```bash
git clone git@github.com:OWNER/REPO.git
```

Before cloning on a cluster, verify the forwarded GitHub identity:

```bash
ssh <cluster> 'ssh -o StrictHostKeyChecking=accept-new -T git@github.com'
```

Expected success looks like `Hi <github-user>! You've successfully authenticated...`. If the cluster says `Permission denied (publickey)`, check that the local machine has the GitHub key loaded in `ssh-agent` and that the cluster SSH connection was opened after `ForwardAgent yes` was installed.

## MFA Warmup

For machines that should keep Alliance SSH sessions ready for agents, install the macOS scheduled warmup:

```bash
bash scripts/install_mfa_warmup_launchd.sh
```

This runs `scripts/mfa_warmup.sh` every day at 09:00 and 19:00 local time. It starts normal SSH authentication to MFA-backed Alliance clusters so the user can approve Duo on their phone; it does not approve, bypass, store, or simulate MFA. Default warmup clusters are:

```text
beluga narval cedar killarney
```

Niagara is not warmed by default because it is legacy/decommissioned in the cluster references. Override the list per machine with `SSH_SKILL_MFA_CLUSTERS`, for example:

```bash
SSH_SKILL_MFA_CLUSTERS="beluga narval cedar killarney niagara" bash scripts/install_mfa_warmup_launchd.sh
```

Warmup logs are written to:

```text
~/.local/state/ssh-skill/mfa-warmup.log
```

## Alliance Accounts

Known Aspuru-Guzik group account names:

```text
rrg-aspuru  # RRG/RAC allocation: Accelerating Materials Discovery with Classical and Quantum Computing
def-aspuru  # Default Resource Allocation Project; opportunistic/default jobs
aip-aspuru  # PAICE AI allocation; Killarney currently uses this account
```

Some clusters expose derived Slurm account names, usually with `_cpu` and `_gpu` suffixes. For example, Narval has been observed with:

```text
rrg-aspuru_cpu
rrg-aspuru_gpu
def-aspuru_cpu
def-aspuru_gpu
```

Before submitting on Alliance clusters, verify which account is valid for the selected user and cluster:

```bash
ssh <cluster> 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | grep -E \"^(rrg-aspuru|def-aspuru|aip-aspuru)(_|\\||$)\" || sshare -U $USER || true"'
```

If the user does not specify an account, use the verified `rrg-aspuru` account for normal research jobs, choosing `_cpu` or `_gpu` when the cluster uses suffixes. Use the verified `def-aspuru` account for small/opportunistic/default jobs. Use `aip-aspuru` only for PAICE/AI-specific systems or partitions after live verification. Always include `#SBATCH --account=<account>` for Alliance jobs once selected.

## Operating Rules

- Do not run long calculations on the login node. Use Slurm (`sbatch` for batch jobs, `srun`/`salloc` for interactive allocations).
- Before job submission, identify cluster, working directory, input files, software/module, account, partition/GPU type if needed, CPU/GPU needs, memory, walltime, and output path. Ask if a missing value would make the job unsafe or ambiguous.
- Prefer `$SCRATCH` for active job directories and logs on Alliance clusters. Use `$PROJECT` or `$HOME/projects/<account>` for persistent shared data/results when present. Use `$HOME` mainly for code, configs, and small files.
- Use job-local `$SLURM_TMPDIR`, `/tmp`, or `/scratch/${USER}` for scratch. Copy anything important back to `$SCRATCH`, `$PROJECT`, `$HOME/projects/<account>`, or `$HOME` before the job exits.
- Ask before destructive actions such as deleting data, cancelling someone else's jobs, or overwriting an existing input/output directory.
- Prefer inspecting existing files, modules, Slurm accounts, and partitions on the selected cluster instead of assuming exact module names or software paths.
- After every submitted job starts running, automatically verify resource utilization. Check that requested GPUs are busy, requested CPU cores are actually used, and requested memory is reasonable. Jobs that reserve many resources while leaving GPUs/CPUs idle should be flagged quickly; ask the user whether to cancel or downsize, and cancel only with user approval unless the user preauthorized automatic cancellation.
- When reporting back in Slack or chat, include the cluster, command outcome, job id if submitted, working directory, log/output file, and the next monitoring command.

## Post-Submit Monitoring

For full details, load `references/monitoring.md`.

After `sbatch` returns a job id, the agent must monitor the job until it is either pending with a clear reason, starts running and passes a utilization check, fails, or the user tells the agent to stop monitoring.

Preferred helper:

```bash
bash scripts/monitor_job.sh <cluster> <jobid>
```

Default workflow:

```bash
jobid=JOBID
squeue -j "$jobid" -o "%.18i %.9P %.8T %.10M %.6D %.20R %.50j"
scontrol show job "$jobid"
```

When the job enters `RUNNING`, identify allocated nodes:

```bash
squeue -j "$jobid" -h -o "%N"
scontrol show hostnames "$(squeue -j "$jobid" -h -o "%N")"
```

Then sample utilization from inside the allocation when possible:

```bash
srun --jobid="$jobid" --overlap --pty bash -lc 'hostname; uptime; ps -u "$USER" -o pid,ppid,pcpu,pmem,etime,cmd --sort=-pcpu | head -25'
```

For GPU jobs, also sample every allocated GPU:

```bash
srun --jobid="$jobid" --overlap --pty bash -lc 'nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader,nounits || true'
```

For memory efficiency after or during a run:

```bash
sstat -j "${jobid}.batch" --format=JobID,AveCPU,AveRSS,MaxRSS,MaxVMSize 2>/dev/null || true
sacct -j "$jobid" --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,AveCPU,ExitCode
```

Heuristics:

- GPU jobs should show sustained nontrivial GPU utilization after warmup. If requested GPUs sit near 0 percent for more than a few sampling intervals after initialization, flag the job as underutilizing GPUs.
- CPU jobs should use a meaningful fraction of requested cores after warmup. If a job asks for N cores but only one process/thread is active, flag it as oversized.
- Memory requests should leave enough headroom to be safe, but not reserve vastly more memory than observed. If `MaxRSS` is far below requested memory after representative runtime, suggest reducing memory next run.
- If monitoring reveals idle expensive resources, report the evidence, suggest a smaller resource request, and ask before cancelling unless the user explicitly authorized automatic cancellation.

## Common Commands

```bash
ssh <cluster> 'bash -lc "hostname; whoami; pwd"'
ssh <cluster> 'bash -lc "sinfo"'
ssh <cluster> 'bash -lc "squeue -u $USER"'
ssh <cluster> 'bash -lc "module avail 2>&1 | head -200"'
ssh <cluster> 'bash -lc "sacct -u $USER --starttime today --format=JobID,JobName,State,Elapsed,ExitCode"'
ssh <cluster> 'bash -lc "sacctmgr -nP show assoc user=$USER format=Account,Partition,QOS%30 2>/dev/null | sort -u || sshare -U $USER || true"'
ssh <cluster> 'bash -lc "printf \"HOME=%s\\nSCRATCH=%s\\nPROJECT=%s\\nSLURM_TMPDIR=%s\\n\" \"$HOME\" \"${SCRATCH:-}\" \"${PROJECT:-}\" \"${SLURM_TMPDIR:-}\""'
```

## ORCA 6 Pattern

For ORCA requests, first choose the cluster and load its exact reference file, for example `references/mariana.md`, `references/narval.md`, or `references/cedar.md`.

1. Check how ORCA is installed on the selected cluster (`module avail`, `module spider`, `which orca`, or known local docs).
2. Keep ORCA CPU parallelism consistent with Slurm resources. If requesting `--ntasks=8`, the ORCA input should typically include `%pal nprocs 8 end`.
3. Use CPU nodes unless the user explicitly has a GPU-capable ORCA workflow.
4. Run ORCA through an `sbatch` script, not directly on the login node.
5. Put temporary files in `$SLURM_TMPDIR`, `/tmp`, `/scratch/${USER}`, or the cluster's documented scratch path. Keep final `.out`, `.gbw`, `.xyz`, and other requested outputs in the working directory, `$SCRATCH`, `$PROJECT`, `$HOME/projects/<account>`, or `/project/${USER}`.

Minimal CPU ORCA job shape:

```bash
#!/bin/bash
#SBATCH --job-name=orca_job
#SBATCH --account=ACCOUNT_CHANGEME
#SBATCH --time=24:00:00
#SBATCH --ntasks=8
#SBATCH --mem-per-cpu=4G
#SBATCH --output=%x-%j.out

set -euo pipefail

module purge
# Load the ORCA 6 environment discovered on the selected cluster, for example:
# module load orca/6.1.1

export OMP_NUM_THREADS=1
export TMPDIR="${SLURM_TMPDIR:-${TMPDIR:-/tmp}}"

orca input.inp > input.out
```
