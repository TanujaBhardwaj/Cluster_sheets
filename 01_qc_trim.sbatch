#!/bin/bash
#SBATCH --job-name=qc_trim
#SBATCH --array=1-15                 # = number of samples in samples.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00              # honest estimate (rule: don't over-request)
#SBATCH --output=logs/qc_trim_%A_%a.out
#SBATCH --error=logs/qc_trim_%A_%a.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=Enter email address here

# ============ CONFIG ============
PROJECT=file location
RAWDIR=${PROJECT}/rawdata
TRIMDIR=${PROJECT}/trimmed
QCRAW=${PROJECT}/qc/fastqc_raw
QCTRIM=${PROJECT}/qc/fastqc_trimmed
SAMPLES=${PROJECT}/samples.txt
THREADS=${SLURM_CPUS_PER_TASK}
# ================================

set -euo pipefail
cd "$PROJECT"
mkdir -p "$TRIMDIR" "$QCRAW" "$QCTRIM" logs

# ---- provenance: record where/what ran (reproducibility + troubleshooting) ----
echo "=== job $SLURM_JOB_ID task $SLURM_ARRAY_TASK_ID on $(hostname) at $(date) ==="
which fastqc fastp
fastqc --version; fastp --version 2>&1 | head -1
# ------------------------------------------------------------------------------

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES")
R1=${RAWDIR}/${SAMPLE}_R1_001.fastq.gz
R2=${RAWDIR}/${SAMPLE}_R2_001.fastq.gz
echo "Sample: $SAMPLE"

# 1) FastQC on raw reads
fastqc -t "$THREADS" -o "$QCRAW" "$R1" "$R2"

# 2) fastp: adapter + quality trimming (auto-detect adapters for paired-end)
fastp \
  -i "$R1" -I "$R2" \
  -o "${TRIMDIR}/${SAMPLE}_R1.trimmed.fastq.gz" \
  -O "${TRIMDIR}/${SAMPLE}_R2.trimmed.fastq.gz" \
  --detect_adapter_for_pe \
  --qualified_quality_phred 20 \
  --length_required 30 \
  --thread "$THREADS" \
  --json "${QCTRIM}/${SAMPLE}.fastp.json" \
  --html "${QCTRIM}/${SAMPLE}.fastp.html"

# 3) FastQC on trimmed reads
fastqc -t "$THREADS" -o "$QCTRIM" \
  "${TRIMDIR}/${SAMPLE}_R1.trimmed.fastq.gz" \
  "${TRIMDIR}/${SAMPLE}_R2.trimmed.fastq.gz"

echo "Done: $SAMPLE at $(date)"
