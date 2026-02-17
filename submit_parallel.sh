#!/bin/bash

# Helper script to submit ENA download as SLURM array job
# Usage: ./submit_parallel.sh <accessions_file> [array_size]

if [ -z "$1" ]; then
    echo "Usage: $0 <accessions_file> [array_size]"
    echo ""
    echo "Arguments:"
    echo "  accessions_file  - File containing one SRA/ENA accession per line"
    echo "  array_size       - Number of parallel jobs (default: 10)"
    echo ""
    echo "Examples:"
    echo "  $0 accessions.txt        # Split into 10 parallel jobs"
    echo "  $0 accessions.txt 5      # Split into 5 parallel jobs"
    echo "  $0 accessions.txt 20     # Split into 20 parallel jobs"
    echo ""
    echo "Note: Accessions will be evenly distributed across array jobs."
    echo "Each job processes multiple accessions."
    exit 1
fi

ACCESSIONS_FILE="$1"
ARRAY_SIZE="${2:-10}"  # Default to 10 parallel jobs

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

# Limit array size to number of accessions
if [ $ARRAY_SIZE -gt $NUM_ACCESSIONS ]; then
  ARRAY_SIZE=$NUM_ACCESSIONS
  echo "Note: Array size reduced to $ARRAY_SIZE (number of accessions)"
fi

# Calculate accessions per job
ACCESSIONS_PER_JOB=$(( (NUM_ACCESSIONS + ARRAY_SIZE - 1) / ARRAY_SIZE ))

# Create logs directory in the same location as accessions file
LOGS_DIR="${ACCESSIONS_DIR}/logs"
mkdir -p "$LOGS_DIR"

echo "Found $NUM_ACCESSIONS accessions in $ACCESSIONS_FILE"
echo "Splitting into $ARRAY_SIZE parallel jobs (~$ACCESSIONS_PER_JOB accessions per job)"
echo "Output directory: $ACCESSIONS_DIR"
echo "Logs directory: $LOGS_DIR"
echo ""

# Get the directory where this script is located (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get absolute paths to the scripts
SUBMIT_SCRIPT="${SCRIPT_DIR}/submit_ena_download.sh"
DOWNLOAD_SCRIPT="${SCRIPT_DIR}/ena-file-download-read_run-search-fastq_ftp.sh"

# Verify scripts exist
if [ ! -f "$SUBMIT_SCRIPT" ]; then
    echo "Error: Cannot find submit_ena_download.sh at: $SUBMIT_SCRIPT"
    exit 1
fi

if [ ! -f "$DOWNLOAD_SCRIPT" ]; then
    echo "Error: Cannot find ena-file-download-read_run-search-fastq_ftp.sh at: $DOWNLOAD_SCRIPT"
    exit 1
fi

# Submit the array job
# Each task will process a chunk of accessions
echo "Submitting SLURM array job..."
sbatch --array=1-${ARRAY_SIZE} \
  --export=DOWNLOAD_SCRIPT="$DOWNLOAD_SCRIPT" \
  --output="${LOGS_DIR}/ena_download_%A_%a.log" \
  --error="${LOGS_DIR}/ena_download_%A_%a.err" \
  "$SUBMIT_SCRIPT" "$ACCESSIONS_FILE_ABS"

echo ""
echo "Job submitted! Monitor progress with:"
echo "  squeue -u \$USER"
echo "  tail -f logs/ena_download_*.log"
echo ""
echo "After all jobs complete, check samplesheet.csv for the results."
