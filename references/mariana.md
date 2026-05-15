# Mariana Cluster Reference

## Access

Login node:

```bash
ssh mariana
```

The generated local alias maps to `mariana.matter.sandbox` by default using `SSH_SKILL_MATTER_USER`. Users normally authenticate with their CSLab login. Mariana is reachable from the CS network; otherwise use the CS VPN or an appropriate SSH bastion. Override `SSH_SKILL_MARIANA_HOST` in the local env file if the hostname changes.

Report cluster problems to Chris Crebolder.

## Monitoring Requirement

After every `sbatch` submission, follow `references/monitoring.md`: monitor until the job is pending with a clear reason or running, then check CPU/GPU/memory utilization. Flag jobs that reserve GPUs, CPU cores, or memory without using them.

## Hardware

CPU nodes:

- 48 CPUs.
- 384 GB memory, with about 4 GB reserved for OS and management.

Imported 40-core CPU nodes:

- 40 physical CPUs, hyperthreading enabled, appearing as 80 CPUs.
- 188 GB memory, with about 4 GB reserved.
- No dedicated disks, including no local scratch disk.

GPU nodes:

- 16 CPUs.
- 384 GB memory, with about 4 GB reserved.
- 4 GeForce RTX 2070 GPUs per node. One node also has an RTX 5000 Ada.
- Use 1 GPU per 4 CPUs when possible. Request multiple GPUs only if the code uses them.

## Storage

Home:

- Path: `/u/$USER` and `$HOME`.
- Network-mounted CSLab home storage, also available on workstations.
- Can be slow and quota-limited. Best for code and copied-back results.

Project:

- Path: `/project/${USER}`.
- Network-mounted large storage array.
- Usually the right place for large datasets and persistent calculation outputs.

Temp and scratch:

- Slurm maps `/tmp` to the same disk as `/scratch` on job startup and deletes the private job temp area when the job ends.
- Node-local scratch is `/scratch`; if not using the `/tmp` mapping, create a user directory with `mkdir -p /scratch/${USER}` in the job script.
- Copy important files from `/tmp`, `/scratch`, or `/dev/shm` to `$HOME` or `/project/${USER}` before the job exits.

RAM disk:

- Path: `/dev/shm`.
- Fastest scratch when spare memory is available.
- Volatile; copy results out before the job ends.

## Software Environment

Most software is exposed through environment modules. Start by checking:

```bash
module avail
```

Known module examples from the cluster notes include:

```text
anaconda/3.6
cuda/10.1
cuda/10.2
cuda/11.1
gaussian/16
gaussian/16C01
Multiwfn/3.7
openeye/2021.2.0
openmpi/4.1.1
python/2-intel-20195098
python/3-intel-20195098
python/3.6a
python/3.8a
vasp/6.2.0
vasp-vtst/6.2.0-3.2
```

Compute Canada / Digital Research Alliance modules may also be available:

```bash
source /cvmfs/soft.computecanada.ca/config/profile/bash.sh
module avail
```

Do not assume a module exists just because it is in this reference. Check on Mariana first.

## Interactive Sessions

Basic shell on a compute node:

```bash
srun --pty bash
```

CPU allocation:

```bash
srun --partition=cpunodes --ntasks=4 --pty bash
```

GPU allocation:

```bash
srun --gres=gpu:2 --ntasks=4 --mem=10000 --pty bash
nvidia-smi
```

Specific GPU examples:

```bash
srun --gres=gpu:rtx2070:2 --ntasks=8 --mem=32000 --pty bash
srun --gres=gpu:rtx5000:1 --ntasks=4 --mem=32000 --pty bash
```

## Batch Jobs

Submit from the login node:

```bash
sbatch jobscript.sh
```

Common monitoring:

```bash
squeue -u "$USER"
sacct -u "$USER" --starttime today --format=JobID,JobName,State,Elapsed,ExitCode
scancel JOBID
tail -n 80 LOGFILE
```

CPU template:

```bash
#!/bin/bash
#SBATCH --job-name=cpu_job
#SBATCH --partition=cpunodes
#SBATCH --time=24:00:00
#SBATCH --ntasks=4
#SBATCH --mem-per-cpu=4G
#SBATCH --output=%x-%j.out

set -euo pipefail

module purge
# module load python/3.8a

mkdir -p "/scratch/${USER}"
export TMPDIR="${TMPDIR:-/tmp}"

# Run code here.
```

GPU template:

```bash
#!/bin/bash
#SBATCH --job-name=gpu_job
#SBATCH --time=72:00:00
#SBATCH --gres=gpu:1
#SBATCH --ntasks=4
#SBATCH --mem-per-cpu=16G
#SBATCH --output=%x-%j.out

set -euo pipefail

module purge
module load cuda

source /opt/python/3.8a/bin/activate
# conda activate myenv

nvidia-smi
# Run GPU code here.
```

## ORCA 6 Workflow

Use this pattern for Slack requests like "run this ORCA calculation" or "submit ORCA 6 on Mariana."

1. Create or identify a working directory, preferably under `/project/${USER}` for real jobs.
2. Put the `.inp` file and any required geometry/basis/auxiliary files there.
3. Verify ORCA availability:

```bash
module avail 2>&1 | grep -i orca || true
source /cvmfs/soft.computecanada.ca/config/profile/bash.sh
module avail 2>&1 | grep -i orca || true
which orca || true
```

4. Match ORCA parallelism to Slurm:

```text
%pal nprocs 8 end
```

with:

```bash
#SBATCH --ntasks=8
export OMP_NUM_THREADS=1
```

5. Submit via Slurm:

```bash
sbatch orca_job.sh
```

ORCA CPU job template:

```bash
#!/bin/bash
#SBATCH --job-name=orca_job
#SBATCH --partition=cpunodes
#SBATCH --time=24:00:00
#SBATCH --ntasks=8
#SBATCH --mem-per-cpu=4G
#SBATCH --output=%x-%j.slurm.out

set -euo pipefail

module purge
# Load the discovered ORCA 6 module or environment here.
# module load orca/6

export OMP_NUM_THREADS=1
export TMPDIR="${TMPDIR:-/tmp}"

orca input.inp > input.out
```

If ORCA is not on `PATH` after module loading, use the discovered absolute executable path. Do not invent one. Check `input.out` and the Slurm log for normal termination or errors.

## Direct SSH To Compute Nodes

SSH to compute nodes is blocked unless the user has an active job or allocation there. If allowed by Slurm, this can be used to inspect files and logs on an allocated node:

```bash
squeue -u "$USER"
ssh NODE_NAME
```

If access is denied by `pam_slurm_adopt`, the user has no active job on that node.

## Response Checklist

When a job is submitted, report:

- Slurm job id.
- Working directory.
- Script path.
- Main output/log file.
- Resource request.
- Monitoring command, usually `squeue -u $USER` or `sacct ...`.

When a command fails, report the failed command, the important stderr/stdout lines, and the next diagnostic step.
