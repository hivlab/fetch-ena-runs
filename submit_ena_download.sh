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

# Get absolute path to the directory containing the accessions file
ACCESSIONS_DIR=$(dirname "$(realpath "$ACCESSIONS_FILE")")
ACCESSIONS_BASENAME=$(basename "$ACCESSIONS_FILE")

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the download script with absolute path to accessions file
"${SCRIPT_DIR}/ena-file-download-read_run-search-fastq_ftp.sh" "${ACCESSIONS_DIR}/${ACCESSIONS_BASENAME}"

echo "Task $SLURM_ARRAY_TASK_ID completed"
