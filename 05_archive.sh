#!/bin/bash
# =====================================================================
# 05_archive.sh  --  RUN ON max-login AFTER the run is verified.
# Follows the Max Cluster "good data-usage workflow" (slides 45-46):
#   keep small results, relocate to /data for long-term storage with a
#   bandwidth-limited rsync, then free the big intermediates off /fast.
#
# Edit DEST to your group's /data area before running.
# =====================================================================
set -euo pipefail

PROJECT=/fast/AG_Izsvak/Tanuja/piggy
DEST=/data/izsvak/Tanuja/piggy

echo "### 1. Sanity check: results exist before we touch anything"
test -s "$PROJECT/counts/counts_matrix.tsv" || { echo "No counts matrix -- aborting."; exit 1; }
test -f "$PROJECT/multiqc/multiqc_report.html" || { echo "No MultiQC report -- aborting."; exit 1; }

echo "### 2. Copy the keepers to /data (single rsync, bandwidth-limited per rules)"
mkdir -p "$DEST"
# --bwlimit=50000 kB/s (~50 MB/s) reflects /data server bandwidth. Do NOT run
# multiple rsyncs in parallel.
rsync -av --bwlimit=50000 \
  "$PROJECT/counts" \
  "$PROJECT/multiqc" \
  "$PROJECT/qc" \
  "$PROJECT/samples.txt" \
  "$PROJECT/manifest.scm" \
  "$PROJECT/logs" \
  "$DEST"/

echo "### 3. (OPTIONAL) free large intermediates from expensive /fast storage"
echo "    Review first, then uncomment the lines you want."
# Trimmed FASTQs (regenerable from rawdata):
#   rm -rf "$PROJECT/trimmed"
# Aligned BAMs (large; keep only if you'll revisit alignments):
#   rm -rf "$PROJECT/aligned"
# NOTE: snapshots mean freed space returns after ~24 h (hourly) / up to 6 months
#       (weekly). This is expected behaviour, not a bug (slide 45).

echo "### Archive step complete. Long-term copy at: $DEST"
