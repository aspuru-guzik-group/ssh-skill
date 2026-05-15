# Resource Monitoring

Use this after every `sbatch` submission. The goal is to avoid idle GPUs, idle CPU cores, and oversized memory requests.

## Required Behavior

After submitting a job:

1. Capture the Slurm job id.
2. Watch the job until it is pending with a clear reason, running and utilization has been sampled, failed, completed quickly, or the user asks you to stop.
3. When the job starts running, sample CPU, GPU, and memory utilization using the commands below.
4. If utilization is poor, report evidence and ask whether to cancel/downsize. Do not cancel unless the user has preauthorized cancellation or confirms it.
5. For future reruns, reduce over-requested CPUs, GPUs, or memory based on measured usage.

Preferred helper from the skill directory:

```bash
bash scripts/monitor_job.sh <cluster> <jobid>
```

If the helper cannot run in the current agent environment, use the manual commands below.

## Slurm State

```bash
jobid=JOBID
squeue -j "$jobid" -o "%.18i %.9P %.8T %.10M %.6D %.20R %.50j"
scontrol show job "$jobid"
```

Allocated nodes:

```bash
nodes="$(squeue -j "$jobid" -h -o "%N")"
scontrol show hostnames "$nodes"
```

## CPU And Process Utilization

Use `srun --overlap` where the cluster permits it:

```bash
srun --jobid="$jobid" --overlap --pty bash -lc 'hostname; uptime; ps -u "$USER" -o pid,ppid,pcpu,pmem,etime,cmd --sort=-pcpu | head -25'
```

If overlap is unavailable, use `sacct`, logs, or SSH to allocated nodes when site policy permits:

```bash
sacct -j "$jobid" --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,AveCPU,ExitCode
sstat -j "${jobid}.batch" --format=JobID,AveCPU,AveRSS,MaxRSS,MaxVMSize 2>/dev/null || true
```

## GPU Utilization

For GPU jobs, sample all allocated GPUs:

```bash
srun --jobid="$jobid" --overlap --pty bash -lc 'nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader,nounits || true'
```

If `srun --overlap` is blocked, inspect the job's node list and use allowed node SSH only if the user has an active allocation there.

## Heuristics

- GPU jobs should show sustained nontrivial GPU utilization after initialization. If requested GPUs remain near 0 percent for several samples, flag the job.
- CPU jobs should use a meaningful fraction of requested cores after warmup. If a job asks for N cores but only one process/thread is active, flag it.
- Memory requests should include safe headroom, but not be much larger than observed `MaxRSS` after representative runtime.
- Multi-GPU jobs must use all requested GPUs. If 10 GPUs are requested, all 10 should show meaningful utilization unless the workflow is intentionally staged.
- Prefer reducing resources on the next run before letting underutilized jobs consume allocation for hours.

## Reporting

When reporting a submitted job, include:

```text
cluster
job id
state
nodes
requested CPUs/GPUs/memory/time
observed CPU/GPU/memory utilization
logs/output path
recommended action: continue, monitor more, downsize next run, or cancel/resubmit
```
