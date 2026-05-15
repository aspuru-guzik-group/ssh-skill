#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/monitor_job.sh <cluster> <jobid> [max_wait_seconds] [sample_interval_seconds]

Poll a Slurm job over SSH and sample CPU/GPU/memory utilization once it starts.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "$#" -lt 2 ]; then
  usage
  exit 2
fi

cluster="$1"
jobid="$2"
max_wait="${3:-900}"
interval="${4:-30}"

case "$cluster" in
  mariana|comte|narval|cedar|killarney) ;;
  *)
    printf 'Unknown cluster: %s\n' "$cluster" >&2
    exit 2
    ;;
esac

case "$jobid" in
  ''|*[!0-9]*) printf 'Job id must be numeric: %s\n' "$jobid" >&2; exit 2 ;;
esac

remote() {
  ssh "$cluster" bash -lc "$1"
}

start_ts="$(date +%s)"

printf 'Monitoring %s job %s\n' "$cluster" "$jobid"

while :; do
  state_line="$(remote "squeue -h -j '$jobid' -o '%T|%R|%N|%M|%D' 2>/dev/null || true")"
  if [ -z "$state_line" ]; then
    printf '\nJob is no longer in squeue. Accounting summary:\n'
    remote "sacct -j '$jobid' --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,AveCPU,ExitCode 2>/dev/null || true"
    exit 0
  fi

  state="${state_line%%|*}"
  printf '\n%s\n' "$(date)"
  printf 'State: %s\n' "$state_line"

  case "$state" in
    RUNNING|COMPLETING)
      break
      ;;
    FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|PREEMPTED)
      printf 'Job reached terminal/problem state: %s\n' "$state" >&2
      remote "sacct -j '$jobid' --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,AveCPU,ExitCode 2>/dev/null || true"
      exit 1
      ;;
  esac

  now="$(date +%s)"
  if [ "$((now - start_ts))" -ge "$max_wait" ]; then
    printf 'Job did not start within %s seconds. Leaving it queued.\n' "$max_wait"
    remote "squeue -j '$jobid' -o '%.18i %.9P %.8T %.10M %.6D %.20R %.50j'"
    exit 0
  fi

  sleep "$interval"
done

printf '\nJob is running. Slurm details:\n'
remote "squeue -j '$jobid' -o '%.18i %.9P %.8T %.10M %.6D %.20R %.50j'; scontrol show job '$jobid' | sed -n '1,80p'"

printf '\nAllocated nodes:\n'
remote "nodes=\$(squeue -j '$jobid' -h -o '%N'); printf '%s\n' \"\$nodes\"; scontrol show hostnames \"\$nodes\" 2>/dev/null || true"

printf '\nCPU/process sample:\n'
remote "srun --jobid='$jobid' --overlap --pty bash -lc 'hostname; uptime; ps -u \"\$USER\" -o pid,ppid,pcpu,pmem,etime,cmd --sort=-pcpu | head -25' 2>/dev/null || true"

printf '\nGPU sample, if GPUs are present:\n'
remote "srun --jobid='$jobid' --overlap --pty bash -lc 'nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader,nounits || true' 2>/dev/null || true"

printf '\nMemory/accounting sample:\n'
remote "sstat -j '${jobid}.batch' --format=JobID,AveCPU,AveRSS,MaxRSS,MaxVMSize 2>/dev/null || true; sacct -j '$jobid' --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,AveCPU,ExitCode 2>/dev/null || true"

printf '\nReview the samples above. If GPUs/CPUs are idle or memory is badly oversized after warmup, ask whether to cancel/downsize and resubmit.\n'
