#!/bin/bash

# Check if accessions file is provided
if [ -z "$1" ]; then
  echo "Error: Please provide an accessions file"
  echo "Usage: $0 <accessions_file>"
  exit 1
fi

# Get the directory of the accessions file
ACCESSIONS_FILE="$1"
ACCESSIONS_DIR=$(dirname "$(realpath "$ACCESSIONS_FILE")")

# Create fastq directory in the same location as accessions file
FASTQ_DIR="${ACCESSIONS_DIR}/fastq"
mkdir -p "$FASTQ_DIR"

# Initialize samplesheet in the same directory as accessions file
SAMPLESHEET="${ACCESSIONS_DIR}/samplesheet.csv"

# Initialize samplesheet
if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
  # In SLURM array mode, create header only from task 1 (or if file doesn't exist)
  if [ "$SLURM_ARRAY_TASK_ID" -eq 1 ] || [ ! -f "$SAMPLESHEET" ]; then
    echo "sample,fastq_1,fastq_2" > "$SAMPLESHEET"
  fi

  # Calculate which accessions this task should process
  TOTAL_ACCESSIONS=$(wc -l < "$ACCESSIONS_FILE")
  ARRAY_SIZE=${SLURM_ARRAY_TASK_COUNT:-1}

  # Calculate chunk size (round up)
  CHUNK_SIZE=$(( (TOTAL_ACCESSIONS + ARRAY_SIZE - 1) / ARRAY_SIZE ))

  # Calculate start and end lines for this task
  START_LINE=$(( (SLURM_ARRAY_TASK_ID - 1) * CHUNK_SIZE + 1 ))
  END_LINE=$(( SLURM_ARRAY_TASK_ID * CHUNK_SIZE ))

  # Don't go beyond the file
  [ $END_LINE -gt $TOTAL_ACCESSIONS ] && END_LINE=$TOTAL_ACCESSIONS

  echo "SLURM Array Task $SLURM_ARRAY_TASK_ID/$ARRAY_SIZE"
  echo "Processing accessions $START_LINE to $END_LINE (of $TOTAL_ACCESSIONS total)"
else
  # Not in array mode, create new samplesheet
  echo "sample,fastq_1,fastq_2" > "$SAMPLESHEET"
  START_LINE=1
  END_LINE=$(wc -l < "$ACCESSIONS_FILE")
fi

# Function to verify MD5 checksum
verify_md5() {
    local file="$1"
    local expected_md5="$2"

    if [ ! -f "$file" ]; then
        return 1  # File doesn't exist
    fi

    # Calculate MD5 sum of the file
    local calculated_md5=$(md5sum "$file" | cut -d' ' -f1)

    if [ "$calculated_md5" == "$expected_md5" ]; then
        return 0  # MD5 matches
    else
        return 1  # MD5 mismatch
    fi
}

# Process accessions in the assigned range
line_num=0
while IFS= read -r line
do
  line_num=$((line_num + 1))
  [ -z "$line" ] && continue

  # Skip lines outside our assigned range
  [ $line_num -lt $START_LINE ] && continue
  [ $line_num -gt $END_LINE ] && break

  echo ""
  echo "=== Processing accession $line_num/$TOTAL_ACCESSIONS: $line ==="

  # Query ENA API and get URLs and MD5 sums
  response=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
    -d "result=read_run&query=accession%3D%22$line%22&fields=run_accession%2Cfastq_ftp%2Cfastq_md5&format=tsv" \
    "https://www.ebi.ac.uk/ena/portal/api/search" | tail -n +2)

  # Extract URLs and MD5s (separated by semicolons for paired reads)
  urls=$(echo "$response" | cut -f 2 | tr ';' '\n')
  md5s=$(echo "$response" | cut -f 3 | tr ';' '\n')

  # Track files for this sample
  sample_files=()

  # Process each file by reading URLs and MD5s in parallel
  while IFS= read -r url && IFS= read -r expected_md5 <&3; do
    # Skip empty lines
    [ -z "$url" ] && continue

    filename=$(basename "$url")
    filepath="$FASTQ_DIR/$filename"

    # Check if file exists and verify MD5
    if verify_md5 "$filepath" "$expected_md5"; then
      echo "✓ $filename already exists with correct MD5 sum, skipping"
    else
      if [ -f "$filepath" ]; then
        echo "✗ $filename exists but MD5 mismatch, redownloading..."
        rm -f "$filepath"
      else
        echo "⬇ Downloading $filename..."
      fi

      # Download the file to fastq directory with progress bar
      wget --progress=bar:force --show-progress -P "$FASTQ_DIR" "$url"

      # Verify the downloaded file
      if verify_md5 "$filepath" "$expected_md5"; then
        echo "✓ $filename downloaded and verified successfully"
      else
        echo "✗ ERROR: $filename MD5 verification failed after download!"
      fi
    fi

    # Add to sample files list
    sample_files+=("$filepath")
  done < <(echo "$urls") 3< <(echo "$md5s")

  # Add entry to samplesheet (with file locking in SLURM array mode)
  (
    if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
      # Use file locking to prevent race conditions
      flock -x 200
    fi

    if [ ${#sample_files[@]} -eq 1 ]; then
      # Single-end: fastq_1 only
      echo "$line,${sample_files[0]}," >> "$SAMPLESHEET"
    elif [ ${#sample_files[@]} -eq 2 ]; then
      # Paired-end: fastq_1 and fastq_2
      echo "$line,${sample_files[0]},${sample_files[1]}" >> "$SAMPLESHEET"
    elif [ ${#sample_files[@]} -gt 2 ]; then
      # More than 2 files (unusual, but handle it)
      echo "$line,${sample_files[0]},${sample_files[1]}" >> "$SAMPLESHEET"
      echo "⚠ Warning: $line has more than 2 FASTQ files, only first 2 added to samplesheet"
    fi
  ) 200>"${SAMPLESHEET}.lock"

done < "$1"

echo ""
echo "✓ Download complete! Samplesheet saved to: $SAMPLESHEET"
