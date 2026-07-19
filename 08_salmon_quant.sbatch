#!/bin/bash
#SBATCH --job-name=salmon_quant
#SBATCH --array=1-15                 # = number of samples in samples.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G                    # decoy index is loaded per task
#SBATCH --time=01:00:00              # honest estimate: ~5-15 min/sample
#SBATCH --output=logs/salmon_quant_%A_%a.out
#SBATCH --error=logs/salmon_quant_%A_%a.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=------@mdc-berlin.de

# =====================================================================
# 08_salmon_quant.sbatch  --  transcript-level quantification.
# Input : the trimmed FASTQs from 01_qc_trim (NOT the STAR BAMs).
# Output: salmon/<SAMPLE>/quant.sf  (+ inferential replicates)
# Run AFTER 07_salmon_index has finished.
# =====================================================================

# ============ CONFIG ============
PROJECT=file location
TRIMDIR=${PROJECT}/trimmed
SALMON_IDX=${PROJECT}/reference/salmon_index_decoy    # <-- or the SHARED index path
QUANTDIR=${PROJECT}/salmon
SAMPLES=${PROJECT}/samples.txt
THREADS=${SLURM_CPUS_PER_TASK}
# ================================

set -euo pipefail
cd "$PROJECT"
mkdir -p "$QUANTDIR" logs

echo "=== salmon_quant job $SLURM_JOB_ID task $SLURM_ARRAY_TASK_ID on $(hostname) at $(date) ==="
which salmon; salmon --version

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES")
R1=${TRIMDIR}/${SAMPLE}_R1.trimmed.fastq.gz
R2=${TRIMDIR}/${SAMPLE}_R2.trimmed.fastq.gz
echo "Quantifying: $SAMPLE"
test -s "$R1" || { echo "Missing $R1"; exit 1; }
test -s "$R2" || { echo "Missing $R2"; exit 1; }

# -l A                 : auto-detect library type (cross-check vs STRAND=2 in 04)
# --seqBias --gcBias   : isoforms of one gene differ in GC/sequence context;
#                        uncorrected bias shows up as a fake isoform switch
# --numGibbsSamples 30 : inferential replicates = read-assignment uncertainty
#                        between isoforms sharing exons. DTU tools use these to
#                        avoid calling switches that are only quantification noise.
# (--validateMappings is the default since salmon 1.0 and no longer needed)
salmon quant \
  -i "$SALMON_IDX" \
  -l A \
  -1 "$R1" -2 "$R2" \
  -p "$THREADS" \
  --seqBias \
  --gcBias \
  --posBias \
  --numGibbsSamples 30 \
  -o "${QUANTDIR}/${SAMPLE}"

echo "--- mapping rate ---"
grep -E 'percent_mapped|num_processed' "${QUANTDIR}/${SAMPLE}/aux_info/meta_info.json" || true
echo "--- detected library type (expect ISR if featureCounts STRAND=2 was right) ---"
grep expected_format "${QUANTDIR}/${SAMPLE}/lib_format_counts.json" || true

echo "Done: $SAMPLE at $(date)"
