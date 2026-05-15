# Comte Cluster Reference

Use this for `/ssh comte ...`.

## Access

Login alias:

```bash
ssh comte
```

The generated local alias maps to `comte.matter.sandbox` by default using `SSH_SKILL_MATTER_USER` and the configured `SSH_SKILL_KEY`. Override `SSH_SKILL_COMTE_HOST` in the local env file if the hostname changes.

## Monitoring Requirement

After every `sbatch` submission, follow `references/monitoring.md`: monitor until the job is pending with a clear reason or running, then check CPU/GPU/memory utilization. Flag jobs that reserve GPUs, CPU cores, or memory without using them.

## Hardware

Live discovery on 2026-05-15 showed Comte behaving like a single workstation rather than a Slurm cluster:

```text
CPU:     Intel Xeon W-2235 @ 3.80 GHz
Cores:   6 physical cores, 12 hardware threads
Memory:  62 GiB RAM, 15 GiB swap
GPUs:    1 NVIDIA RTX A6000
         1 NVIDIA Quadro P1000
Slurm:   sbatch/squeue/sinfo/sacct not found during discovery
```

Do not treat Comte as a shared scheduler-backed cluster unless live discovery later shows a scheduler. Ask before starting long-lived GPU or CPU jobs there.

## Discovery First

Before submitting or changing jobs, inspect the live system:

```bash
ssh comte 'bash -lc "hostname; whoami; pwd; date"'
ssh comte 'bash -lc "command -v sbatch squeue sinfo sacct 2>/dev/null || true"'
ssh comte 'bash -lc "printf \"HOME=%s\nSCRATCH=%s\nPROJECT=%s\nTMPDIR=%s\n\" \"$HOME\" \"${SCRATCH:-}\" \"${PROJECT:-}\" \"${TMPDIR:-}\""'
ssh comte 'bash -lc "sinfo -o \"%P %a %l %D %G\" 2>/dev/null | head -80 || true"'
ssh comte 'bash -lc "squeue -u $USER 2>/dev/null || true"'
ssh comte 'bash -lc "module avail 2>&1 | head -200 || true"'
ssh comte 'bash -lc "lscpu | sed -n \"1,25p\"; free -h; nvidia-smi -L 2>/dev/null || true"'
```

If Slurm is present, follow the generic Slurm rules:

- Do not run long calculations on the login node.
- Use `sbatch` for batch jobs and `srun`/`salloc` for interactive allocations.
- Discover any required partition, account, GPU resource, memory limits, and filesystem policy before submission.
- Report job id, working directory, script path, output/log path, and monitor command.

If Comte is not a Slurm cluster, adapt to the live scheduler or ask the user before running long-lived work.
