#!/bin/bash
#SBATCH --job-name=salmon_index
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G                    # decoy-aware human index peaks ~30-35G
#SBATCH --time=04:00:00
#SBATCH --output=logs/salmon_index_%j.out
#SBATCH --error=logs/salmon_index_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=----@mdc-berlin.de

# =====================================================================

# ============ CONFIG ============
PROJECT=file location
REF=${PROJECT}/reference
GENOME_FA=${REF}/GRCh38.primary_assembly.genome.fa        # same file as 02_star_index
GTF=${REF}/gencode.v46.primary_assembly.annotation.gtf    # same file as 02/04/06
TXFA=${REF}/gencode.v46.transcripts.fa                    # built below by gffread
GENTROME=${REF}/gentrome.fa.gz
DECOYS=${REF}/decoys.txt
SALMON_IDX=${REF}/salmon_index_decoy
TX2GENE=${REF}/tx2gene.tsv
THREADS=${SLURM_CPUS_PER_TASK}
KMER=31          # default; correct for 150 bp reads. Lower only for <50 bp reads.
# ================================

set -euo pipefail
cd "$PROJECT"
mkdir -p "$REF" logs

echo "=== salmon_index job $SLURM_JOB_ID on $(hostname) at $(date) ==="
which salmon gffread
salmon --version
gffread --version

test -s "$GENOME_FA" || { echo "Missing genome FASTA: $GENOME_FA"; exit 1; }
test -s "$GTF"       || { echo "Missing GTF: $GTF"; exit 1; }

echo "### 1. Extract transcript sequences from the GTF used for the STAR index"
# -w = write spliced transcript FASTA. Headers are transcript_id (versioned),
# which is exactly what tximport / IsoformSwitchAnalyzeR expect.
if [[ -s "$TXFA" ]]; then
  echo "    $TXFA exists -- skipping gffread"
else
  gffread -w "$TXFA" -g "$GENOME_FA" "$GTF"
fi
echo "    transcripts: $(grep -c '^>' "$TXFA")"

echo "### 2. Decoy list = every sequence name in the genome"
grep '^>' "$GENOME_FA" | cut -d ' ' -f1 | sed 's/^>//' > "$DECOYS"
echo "    decoys: $(wc -l < "$DECOYS")"

echo "### 3. Gentrome = transcripts + genome (transcripts MUST come first)"
if [[ -s "$GENTROME" ]]; then
  echo "    $GENTROME exists -- skipping"
else
  cat "$TXFA" "$GENOME_FA" | gzip -c > "$GENTROME"
fi

echo "### 4. Build the index"
# NOTE: salmon silently collapses transcripts with identical sequence. That is
# fine (they are unquantifiable apart anyway). Add --keepDuplicates only if a
# downstream tool insists on every annotated transcript being present.
salmon index \
  -t "$GENTROME" \
  -d "$DECOYS" \
  -p "$THREADS" \
  -k "$KMER" \
  -i "$SALMON_IDX"

echo "### 5. tx2gene map (transcript_id -> gene_id), from the same GTF"
awk -F'\t' '$3=="transcript"{
  t=""; g="";
  if (match($9, /transcript_id "[^"]+"/)) { t=substr($9,RSTART+15,RLENGTH-16) }
  if (match($9, /gene_id "[^"]+"/))       { g=substr($9,RSTART+9,RLENGTH-10) }
  if (t!="" && g!="") print t"\t"g
}' "$GTF" | sort -u > "$TX2GENE"
echo "    wrote $TX2GENE ($(wc -l < "$TX2GENE") transcripts)"

echo "### 6. Free the gentrome (regenerable in minutes, ~1 GB on /fast)"
rm -f "$GENTROME"

echo "Index built at: $SALMON_IDX  ($(date))"
