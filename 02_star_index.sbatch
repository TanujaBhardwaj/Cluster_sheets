#!/bin/bash
#SBATCH --job-name=star_index
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=45G                    # human genome index needs ~38-40G
#SBATCH --time=03:00:00
#SBATCH --output=logs/star_index_%j.out
#SBATCH --error=logs/star_index_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=YOUR.NAME@mdc-berlin.de

# =====================================================================
# RUN THIS ONLY IF no shared human STAR index exists.
# ASK FIRST: TP Sequencing / helpdesk@mdc-berlin.de  -- a reusable
# GRCh38 index is ~30 GB; don't duplicate it if one is already on /fast.
# =====================================================================

# ============ CONFIG ============
PROJECT=/fast/AG_Izsvak/Tanuja/piggy
REF=${PROJECT}/reference
GENOME_FA=${REF}/GRCh38.primary_assembly.genome.fa        # unzipped genome FASTA
GTF=${REF}/gencode.v46.primary_assembly.annotation.gtf    # unzipped GTF
INDEX=${REF}/star_index
THREADS=${SLURM_CPUS_PER_TASK}
READLEN=149     # = (read length - 1). 150 bp reads -> 149. CHECK YOUR READ LENGTH.
# ================================

set -euo pipefail
cd "$PROJECT"
mkdir -p "$INDEX" logs

echo "=== star_index job $SLURM_JOB_ID on $(hostname) at $(date) ==="
which STAR; STAR --version

# Download (run on max-login BEFORE submitting, if you must build your own):
#   cd $REF
#   wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_46/GRCh38.primary_assembly.genome.fa.gz
#   wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_46/gencode.v46.primary_assembly.annotation.gtf.gz
#   gunzip *.gz

STAR \
  --runMode genomeGenerate \
  --runThreadN "$THREADS" \
  --genomeDir "$INDEX" \
  --genomeFastaFiles "$GENOME_FA" \
  --sjdbGTFfile "$GTF" \
  --sjdbOverhang "$READLEN"

echo "Index built at: $INDEX  ($(date))"
