#!/bin/bash
# =====================================================================
#
#   counts_with_symbols.tsv : gene_id  gene_name  <15 sample columns>
#   counts_symbols_only.tsv : gene_name <15 sample columns>  (collapsed)
# =====================================================================
set -euo pipefail

PROJECT=file location
GTF=${PROJECT}/reference/gencode.v46.primary_assembly.annotation.gtf
COUNTS=${PROJECT}/counts/counts_matrix.tsv
OUTDIR=${PROJECT}/counts
MAP=${OUTDIR}/gene_id2name.tsv

cd "$PROJECT"

echo "### 1. Build gene_id -> gene_name map from the GTF"
# pull gene_id and gene_name from 'gene' lines; keep the version suffix on the id
awk -F'\t' '$3=="gene"{
  id=""; name="";
  if (match($9, /gene_id "[^"]+"/))   { id=substr($9,RSTART+9,RLENGTH-10) }
  if (match($9, /gene_name "[^"]+"/)) { name=substr($9,RSTART+11,RLENGTH-12) }
  if (name=="") name=id;
  print id"\t"name
}' "$GTF" | sort -u > "$MAP"
echo "    mapped $(wc -l < "$MAP") genes -> $MAP"

echo "### 2. Join names onto the counts matrix (keeps gene_id + adds gene_name)"
# header
{ printf "gene_id\tgene_name"; head -1 "$COUNTS" | cut -f2-; } \
  > "${OUTDIR}/counts_with_symbols.tsv"
# body: look up each gene_id; if unmapped, reuse the id as the name
awk -F'\t' '
  NR==FNR { name[$1]=$2; next }
  FNR==1  { next }
  { n=($1 in name)?name[$1]:$1; printf "%s\t%s", $1, n;
    for(i=2;i<=NF;i++) printf "\t%s", $i; print "" }
' "$MAP" "$COUNTS" >> "${OUTDIR}/counts_with_symbols.tsv"
echo "    wrote ${OUTDIR}/counts_with_symbols.tsv"

echo "### 3. Symbol-only matrix (sum counts per symbol; handles duplicate names)"
# DESeq2 needs unique row names; a few Ensembl IDs share a symbol, so sum them.
{
  printf "gene_name"; head -1 "$COUNTS" | cut -f2-;
  awk -F'\t' '
    NR==FNR { name[$1]=$2; next }
    FNR==1  { ncol=NF; next }
    { n=($1 in name)?name[$1]:$1;
      for(i=2;i<=NF;i++) sum[n SUBSEP i]+=$i; seen[n]=1 }
    END {
      for(g in seen){ printf "%s", g;
        for(i=2;i<=ncol;i++) printf "\t%s", (sum[g SUBSEP i]+0); print "" }
    }
  ' "$MAP" "$COUNTS"
} > "${OUTDIR}/counts_symbols_only.tsv"
echo "    wrote ${OUTDIR}/counts_symbols_only.tsv"

echo
echo "### Done. Quick check on PGBD4:"
grep -P "\tPGBD4\t" "${OUTDIR}/counts_with_symbols.tsv" || echo "    (PGBD4 not found - check symbol spelling)"
