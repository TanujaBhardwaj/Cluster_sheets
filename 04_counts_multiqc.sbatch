#!/bin/bash
#SBATCH --job-name=counts_multiqc
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=logs/counts_%j.out
#SBATCH --error=logs/counts_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=YOUR.NAME@mdc-berlin.de

# ============ CONFIG ============
PROJECT=/fast/AG_Izsvak/Tanuja/piggy
BAMDIR=${PROJECT}/aligned
GTF=${PROJECT}/reference/gencode.v46.primary_assembly.annotation.gtf  # same GTF as the index
COUNTDIR=${PROJECT}/counts
THREADS=${SLURM_CPUS_PER_TASK}
STRAND=2        # set from ReadsPerGene check
# ================================

set -euo pipefail
cd "$PROJECT"
mkdir -p "$COUNTDIR" logs

echo "=== counts_multiqc job $SLURM_JOB_ID on $(hostname) at $(date) ==="
which featureCounts multiqc; featureCounts -v

# featureCounts over ALL BAMs at once -> single counts matrix
# -p --countReadPairs : paired-end, count fragments not reads
featureCounts \
  -T "$THREADS" \
  -p --countReadPairs \
  -s "$STRAND" \
  -a "$GTF" \
  -o "${COUNTDIR}/gene_counts.txt" \
  "${BAMDIR}"/*.Aligned.sortedByCoord.out.bam

# Tidy matrix: gene_id + one column per sample (strip the 5 annotation columns).
# Also clean the header so column names are sample IDs, not full BAM paths.
{
  head -2 "${COUNTDIR}/gene_counts.txt" | tail -1 \
    | cut -f1,7- \
    | sed 's#[^\t]*/##g; s/\.Aligned\.sortedByCoord\.out\.bam//g'
  tail -n +3 "${COUNTDIR}/gene_counts.txt" | cut -f1,7-
} > "${COUNTDIR}/counts_matrix.tsv"
echo "Counts matrix -> ${COUNTDIR}/counts_matrix.tsv"
echo "Assignment summary -> ${COUNTDIR}/gene_counts.txt.summary"

# Aggregate ALL QC (fastqc, fastp, STAR, featureCounts) into one report
multiqc -f -o "${PROJECT}/multiqc" "$PROJECT"

echo "All done at $(date). Open multiqc/multiqc_report.html"
