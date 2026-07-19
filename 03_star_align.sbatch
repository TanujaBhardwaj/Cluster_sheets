#!/bin/bash
#SBATCH --job-name=star_align
#SBATCH --array=1-15
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G                    # human genome shared in RAM per task
#SBATCH --time=04:00:00
#SBATCH --output=logs/star_align_%A_%a.out
#SBATCH --error=logs/star_align_%A_%a.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=YOUR.NAME@mdc-berlin.de

# ============ CONFIG ============
PROJECT=file location
TRIMDIR=${PROJECT}/trimmed
INDEX=${PROJECT}/reference/star_index     # <-- or the SHARED index path, if one exists
BAMDIR=${PROJECT}/aligned
SAMPLES=${PROJECT}/samples.txt
THREADS=${SLURM_CPUS_PER_TASK}
# ================================

set -euo pipefail
cd "$PROJECT"
mkdir -p "$BAMDIR" logs

echo "=== star_align job $SLURM_JOB_ID task $SLURM_ARRAY_TASK_ID on $(hostname) at $(date) ==="
which STAR samtools; STAR --version

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES")
R1=${TRIMDIR}/${SAMPLE}_R1.trimmed.fastq.gz
R2=${TRIMDIR}/${SAMPLE}_R2.trimmed.fastq.gz
echo "Aligning: $SAMPLE"

STAR \
  --runMode alignReads \
  --runThreadN "$THREADS" \
  --genomeDir "$INDEX" \
  --readFilesIn "$R1" "$R2" \
  --readFilesCommand zcat \
  --outSAMtype BAM SortedByCoordinate \
  --quantMode GeneCounts \
  --outFileNamePrefix "${BAMDIR}/${SAMPLE}."

samtools index "${BAMDIR}/${SAMPLE}.Aligned.sortedByCoord.out.bam"

# STRANDEDNESS: after this finishes, inspect ${SAMPLE}.ReadsPerGene.out.tab
#   col2 = unstranded | col3 = forward (-s 1) | col4 = reverse (-s 2)
#   the column with the highest summed counts is your protocol.
echo "Done: $SAMPLE at $(date)"
