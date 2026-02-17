#!/bin/bash
#SBATCH --job-name=ena_download
#SBATCH --output=logs/ena_download_%A_%a.log
#SBATCH --error=logs/ena_download_%A_%a.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G

# Usage: sbatch --array=1-N submit_ena_download.sh accessions.txt
# Where N is the number of accessions in the file

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

# Create logs directory if it doesn't exist
mkdir -p logs

# Run the download script
# The script will automatically detect SLURM_ARRAY_TASK_ID and process the corresponding line
./ena-file-download-read_run-search-fastq_ftp.sh "$ACCESSIONS_FILE"

echo "Task $SLURM_ARRAY_TASK_ID completed"
