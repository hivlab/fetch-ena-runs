#!/bin/bash

# Expand project/study accessions to run accessions using the ENA filereport API.
# Run/sample accessions pass through unchanged.
#
# Recognized project/study patterns:
#   PRJEB.../PRJNA.../PRJDB...   (BioProject)
#   ERP.../SRP.../DRP...         (Study)
#
# Usage: expand_accessions.sh <input_file> <output_file>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_file> <output_file>" >&2
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' not found" >&2
    exit 1
fi

PROJECT_REGEX='^(PRJ[A-Z]+[0-9]+|[ESD]RP[0-9]+)$'

# Fast path: if no project/study IDs in input, just copy
if ! grep -E -q "$PROJECT_REGEX" "$INPUT"; then
    cp "$INPUT" "$OUTPUT"
    exit 0
fi

: > "$OUTPUT"
while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | tr -d '[:space:]')
    [ -z "$line" ] && continue

    if [[ "$line" =~ $PROJECT_REGEX ]]; then
        echo "Expanding $line via ENA API..." >&2
        runs=$(curl -fsS "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${line}&result=read_run&fields=run_accession&format=tsv" \
            | tail -n +2 | cut -f1 | grep -v '^[[:space:]]*$' || true)
        if [ -z "$runs" ]; then
            echo "  Warning: no runs returned for $line" >&2
            continue
        fi
        n=$(echo "$runs" | wc -l | tr -d ' ')
        echo "  found $n run(s)" >&2
        echo "$runs" >> "$OUTPUT"
    else
        echo "$line" >> "$OUTPUT"
    fi
done < "$INPUT"

echo "Wrote expanded run list to $OUTPUT" >&2
