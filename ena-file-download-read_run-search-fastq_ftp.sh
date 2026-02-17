#!/bin/bash

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

while IFS= read -r line
do
  # Query ENA API and get URLs and MD5 sums
  response=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
    -d "result=read_run&query=accession%3D%22$line%22&fields=run_accession%2Cfastq_ftp%2Cfastq_md5&format=tsv" \
    "https://www.ebi.ac.uk/ena/portal/api/search" | tail -n +2)

  # Extract URLs and MD5s (separated by semicolons for paired reads)
  urls=$(echo "$response" | cut -f 2 | tr ';' '\n')
  md5s=$(echo "$response" | cut -f 3 | tr ';' '\n')

  # Convert to arrays
  readarray -t url_array <<< "$urls"
  readarray -t md5_array <<< "$md5s"

  # Process each file
  for i in "${!url_array[@]}"; do
    url="${url_array[$i]}"
    expected_md5="${md5_array[$i]}"

    # Skip empty lines
    [ -z "$url" ] && continue

    filename=$(basename "$url")

    # Check if file exists and verify MD5
    if verify_md5 "$filename" "$expected_md5"; then
      echo "✓ $filename already exists with correct MD5 sum, skipping"
    else
      if [ -f "$filename" ]; then
        echo "✗ $filename exists but MD5 mismatch, redownloading..."
        rm -f "$filename"
      else
        echo "⬇ Downloading $filename..."
      fi

      # Download the file
      wget -q "$url"

      # Verify the downloaded file
      if verify_md5 "$filename" "$expected_md5"; then
        echo "✓ $filename downloaded and verified successfully"
      else
        echo "✗ ERROR: $filename MD5 verification failed after download!"
      fi
    fi
  done
done < "$1"
