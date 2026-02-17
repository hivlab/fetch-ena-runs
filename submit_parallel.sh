#!/bin/bash

# Helper script to submit ENA download as SLURM array job
# Usage: ./submit_parallel.sh accessions.txt

if [ -z "$1" ]; then
    echo "Usage: $0 <accessions_file>"
    echo ""
    echo "This script will submit a SLURM array job to download FASTQ files in parallel."
    echo "Each accession will be processed by a separate job."
    exit 1
fi

ACCESSIONS_FILE="$1"

# Check if file exists
if [ ! -f "$ACCESSIONS_FILE" ]; then
    echo "Error: File '$ACCESSIONS_FILE' not found"
    exit 1
fi

# Get absolute path and directory of accessions file
ACCESSIONS_FILE_ABS=$(realpath "$ACCESSIONS_FILE")
ACCESSIONS_DIR=$(dirname "$ACCESSIONS_FILE_ABS")

# Count number of accessions (non-empty lines)
NUM_ACCESSIONS=$(grep -c -v '^[[:space:]]*$' "$ACCESSIONS_FILE")

if [ "$NUM_ACCESSIONS" -eq 0 ]; then
    echo "Error: No accessions found in '$ACCESSIONS_FILE'"
    exit 1
fi

# Create logs directory in the same location as accessions file
LOGS_DIR="${ACCESSIONS_DIR}/logs"
mkdir -p "$LOGS_DIR"

echo "Found $NUM_ACCESSIONS accessions in $ACCESSIONS_FILE"
echo "Submitting SLURM array job with array size 1-$NUM_ACCESSIONS"
echo "Limiting to 10 parallel downloads at a time (ENA rate limit)"
echo "Output directory: $ACCESSIONS_DIR"
echo "Logs directory: $LOGS_DIR"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Submit the job with max 10 concurrent tasks (ENA rate limit)
# The %10 limits concurrent running tasks to 10
# Set output and error logs to be in the same directory as accessions file
sbatch --array=1-${NUM_ACCESSIONS}%10 \
  --output="${LOGS_DIR}/ena_download_%A_%a.log" \
  --error="${LOGS_DIR}/ena_download_%A_%a.err" \
  "${SCRIPT_DIR}/submit_ena_download.sh" "$ACCESSIONS_FILE_ABS"

echo ""
echo "Job submitted! Monitor progress with:"
echo "  squeue -u \$USER"
echo "  tail -f logs/ena_download_*.log"
echo ""
echo "After all jobs complete, check samplesheet.csv for the results."
