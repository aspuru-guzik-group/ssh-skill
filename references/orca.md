# ORCA Quantum Chemistry Workflow

Use this reference for requests such as "run ORCA", "submit an ORCA job", "check my ORCA output", or quantum chemistry jobs using ORCA on Alliance Canada or Matterlab clusters.

## Ground Rules

- Do not run production ORCA calculations on login nodes.
- Treat ORCA as license- and module-sensitive. If `module load orca/...` fails, report the exact module/licensing message instead of working around access controls.
- Prefer CPU nodes. Only request GPUs when the user's input and installed ORCA build explicitly support the requested GPU workflow.
- Keep Slurm parallelism and ORCA parallelism consistent: `#SBATCH --ntasks=N` should match `%pal nprocs N end` in the input for normal parallel ORCA jobs.
- Set `OMP_NUM_THREADS=1` unless the chosen ORCA method and site documentation say otherwise.
- Do not start the ORCA driver with `mpirun` or `srun`. Call the serial ORCA driver; ORCA starts its parallel modules from the input file.
- For parallel ORCA runs, call ORCA with the full executable path, not just `orca`.

## Discovery

Run discovery on the target cluster before creating the final job script:

```bash
module spider orca 2>&1 | head -120
module spider orca/6.1.1 2>&1 | sed -n '1,120p'
module -t avail orca 2>&1 | sed -n '1,120p'
```

Then test the exact module stack:

```bash
module purge
module load StdEnv/2023 gcc/12.3 openmpi/4.1.5 orca/6.1.1
printf 'EBROOTORCA=%s\n' "${EBROOTORCA:-}"
test -x "${EBROOTORCA}/orca"
"${EBROOTORCA}/orca" --version | head -40
```

If the `gcc/12.3 openmpi/4.1.5` stack is not available, try the alternate stack reported by `module spider`, commonly:

```bash
module purge
module load StdEnv/2023 gcc/14.3 openmpi/5.0.8 orca/6.1.1
```

Live checks on Trillium, Narval, and Killarney on 2026-05-19 showed `orca/6.1.1` with both prerequisite stacks:

```text
StdEnv/2023 gcc/12.3 openmpi/4.1.5
StdEnv/2023 gcc/14.3 openmpi/5.0.8
```

The Alliance ORCA module prints this execution form:

```text
${EBROOTORCA}/orca orca.inp > orca.out
```

Cedar access can require a fresh Duo/session state. Re-run the same discovery there before promising a specific stack.

## Input Checks

Before submission, inspect the `.inp` file:

```bash
grep -inE '^[[:space:]]*%pal|^[[:space:]]*![^#]*PAL|^[[:space:]]*%maxcore' input.inp || true
tail -n 30 input.inp
```

For an 8-task job, the input should usually contain:

```text
%pal nprocs 8 end
```

Set `%maxcore` in MB per ORCA process, then request enough Slurm memory for all processes with headroom. A conservative rule is:

```text
requested memory >= (nprocs * maxcore) / 0.75
```

Example for 8 tasks and `%maxcore 3000`: request at least 32 GB, preferably more for methods that are memory-hungry.

## Alliance Slurm Template

Use this as the starting point for Narval, Cedar, Killarney, and other Alliance Slurm clusters. Adjust account, partition, time, memory, and input name after live discovery.

```bash
#!/bin/bash
#SBATCH --job-name=orca_job
#SBATCH --account=ACCOUNT_CHANGEME
#SBATCH --time=24:00:00
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=1
#SBATCH --mem=40G
#SBATCH --output=%x-%j.slurm.out

set -euo pipefail

input="${1:-input.inp}"
stem="${input%.inp}"
submit_dir="${SLURM_SUBMIT_DIR:-$PWD}"

module purge
module load StdEnv/2023 gcc/12.3 openmpi/4.1.5 orca/6.1.1

export OMP_NUM_THREADS=1
export ORCA_EXE="${EBROOTORCA}/orca"
test -x "$ORCA_EXE"

workdir="${SLURM_TMPDIR:-${TMPDIR:-}}"
if [ -z "$workdir" ]; then
  workdir="$submit_dir/${stem}.scratch.${SLURM_JOB_ID:-manual}"
  mkdir -p "$workdir"
fi

cleanup() {
  status=$?
  mkdir -p "$submit_dir/results-${SLURM_JOB_ID:-manual}"
  find "$workdir" -maxdepth 1 -type f \
    ! -name '*.tmp' \
    ! -name '*.tmp.*' \
    -exec cp -p {} "$submit_dir/results-${SLURM_JOB_ID:-manual}/" \; || true
  exit "$status"
}
trap cleanup EXIT

cp -p "$submit_dir/$input" "$workdir/"
find "$submit_dir" -maxdepth 1 -type f \( \
  -name '*.xyz' -o -name '*.gbw' -o -name '*.hess' -o -name '*.pot' -o -name '*.pc' -o -name '*.bas' \
\) -exec cp -p {} "$workdir/" \; || true

cd "$workdir"
"$ORCA_EXE" "$input" > "${stem}.out"
```

Submit from the directory containing the input:

```bash
sbatch orca_job.sh input.inp
```

For Narval CPU jobs, prefer a verified CPU account such as `rrg-aspuru_cpu`. For Cedar and Trillium, verify the account/partition live. Killarney is GPU-oriented; use it for ORCA only after checking that CPU resources/partitions are appropriate or the user intentionally wants that site.

## Mariana Template

On Mariana, read `references/mariana.md` for storage and partition details. Use the same ORCA rules: discover the module/path first, align `--ntasks` with `%pal`, and use `/tmp`, `/scratch/${USER}`, or `/dev/shm` only as temporary runtime space.

```bash
#!/bin/bash
#SBATCH --job-name=orca_job
#SBATCH --partition=cpunodes
#SBATCH --time=24:00:00
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --output=%x-%j.slurm.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

module purge
# Load the discovered local ORCA module or source the Alliance CVMFS environment first.
# source /cvmfs/soft.computecanada.ca/config/profile/bash.sh
# module load StdEnv/2023 gcc/12.3 openmpi/4.1.5 orca/6.1.1

export OMP_NUM_THREADS=1
export ORCA_EXE="${EBROOTORCA:+${EBROOTORCA}/orca}"
if [ -z "$ORCA_EXE" ]; then
  ORCA_EXE="$(command -v orca || true)"
fi
test -x "$ORCA_EXE"

"$ORCA_EXE" input.inp > input.out
```

## Monitoring And Completion

After `sbatch`, follow `references/monitoring.md`.

Important checks:

```bash
squeue -j JOBID -o "%.18i %.9P %.8T %.10M %.6D %.20R %.50j"
tail -n 80 JOB_OR_ORCA_OUTPUT
grep -n "ORCA TERMINATED NORMALLY" input.out
grep -n "ORCA finished by error termination" input.out
sacct -j JOBID --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS,AveCPU,ExitCode
```

If the output lacks normal termination, inspect the last 100-200 lines of both the ORCA output and Slurm log before resubmitting. Common fixes are input syntax, missing auxiliary files, `%maxcore` too high/low for the requested memory, and `--ntasks` mismatching `%pal`.
