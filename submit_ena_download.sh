#!/bin/bash
#SBATCH --job-name=ena_download
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G

# Usage: sbatch --array=1-N submit_ena_download.sh accessions.txt
# Where N is the number of accessions in the file
# Note: --output and --error must be set when submitting, not here

# Check if accessions file is provided
if [ -z "$1" ]; then
    echo "Error: Please provide an accessions file"
    echo "Usage: sbatch --array=1-N $0 accessions.txt"
    exit 1
fi

ACCESSIONS_FILE="$1"

# Check if file exists
if [ ! -f "$ACCESSIONS_FILE" ]; then
    echo "Error: Accessions file '$ACCESSIONS_FILE' not found"
    exit 1
fi

# Get absolute path to the accessions file
ACCESSIONS_FILE_ABS=$(realpath "$ACCESSIONS_FILE")

# The download script path should be passed via environment variable
# Set by submit_parallel.sh as DOWNLOAD_SCRIPT
if [ -z "$DOWNLOAD_SCRIPT" ]; then
    echo "Error: DOWNLOAD_SCRIPT environment variable not set"
    echo "This script should be called via submit_parallel.sh"
    exit 1
fi

# Run the download script with absolute path
"$DOWNLOAD_SCRIPT" "$ACCESSIONS_FILE_ABS"

echo "Task $SLURM_ARRAY_TASK_ID completed"
