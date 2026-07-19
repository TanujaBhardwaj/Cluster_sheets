#!/bin/bash
#SBATCH --job-name=isoform_dtu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=06:00:00              # DEXSeq over all multi-isoform genes is the slow part
#SBATCH --output=logs/isoform_dtu_%j.out
#SBATCH --error=logs/isoform_dtu_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=---------@mdc-berlin.de

# =====================================================================
# 09_isoform_dtu.sbatch  --  wrapper around 09_isoform_dtu.R.
# This is a compute job, NOT a max-login job: DEXSeq on ~40k genes will
# get you killed on the login node.
# Run AFTER 08_salmon_quant has finished for all 15 samples.
# =====================================================================

# ============ CONFIG ============
PROJECT=file location
RSCRIPT=${PROJECT}/scripts/09_isoform_dtu.R    # <-- adjust if you keep scripts elsewhere
# ================================

set -euo pipefail
cd "$PROJECT"
mkdir -p logs isoform

echo "=== isoform_dtu job $SLURM_JOB_ID on $(hostname) at $(date) ==="
which Rscript; R --version | head -1

test -s "$RSCRIPT"             || { echo "Missing $RSCRIPT"; exit 1; }
test -s "${PROJECT}/design.tsv" || { echo "Missing design.tsv -- see README step 3"; exit 1; }

# Keep BLAS/OpenMP from oversubscribing the allocation
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export OPENBLAS_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export MKL_NUM_THREADS=${SLURM_CPUS_PER_TASK}

Rscript --vanilla "$RSCRIPT"

echo "Done at $(date). Results in ${PROJECT}/isoform/"
