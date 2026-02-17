# ENA FASTQ Downloader

A bash script to download FASTQ files from the European Nucleotide Archive (ENA) with automatic MD5 checksum verification.

## Features

- Download FASTQ files from ENA using SRA/ENA sample accessions
- Automatic MD5 checksum verification
- Skip re-downloading files that already exist with correct checksums
- Automatically redownload files with MD5 mismatches
- Support for paired-end reads (multiple FASTQ files per accession)
- Clear status reporting with visual indicators

## Requirements

- `bash`
- `curl`
- `wget`
- `md5sum`

## Usage

### Local/Sequential Execution

```bash
./ena-file-download-read_run-search-fastq_ftp.sh <accessions_file>
```

### Parallel Execution on SLURM

For faster downloads on HPC clusters, use the SLURM submission script to process all accessions in parallel:

```bash
./submit_parallel.sh <accessions_file>
```

This will automatically:
- Count the number of accessions
- Submit a SLURM array job where each task processes one accession
- Download all samples in parallel across compute nodes

**Manual SLURM submission:**
```bash
# Count accessions
NUM=$(grep -c -v '^[[:space:]]*$' accessions.txt)

# Submit array job (limit to 10 concurrent downloads due to ENA rate limits)
sbatch --array=1-${NUM}%10 submit_ena_download.sh accessions.txt
```

**Note:** The `%10` limits concurrent downloads to 10 at a time to respect ENA's rate limits. Adjust if needed.

### Input Format

Create a text file with one SRA/ENA accession per line:

```
SRR123456
SRR123457
SRR123458
```

The script accepts various accession formats:
- SRA run accessions (e.g., `SRR123456`, `ERR123456`, `DRR123456`)
- ENA run accessions (e.g., `ERR123456`)
- Sample accessions (e.g., `SAMN123456`, `ERS123456`)

## Example

1. Create an accessions file:
```bash
cat > accessions.txt << EOF
SRR12345678
SRR12345679
EOF
```

2. Run the script:
```bash
./ena-file-download-read_run-search-fastq_ftp.sh accessions.txt
```

## Output

The script will:
- Download FASTQ files to the `fastq/` directory
- Generate a `samplesheet.csv` file with sample metadata
- Display status messages:

```
✓ SRR12345678_1.fastq.gz already exists with correct MD5 sum, skipping
✗ SRR12345678_2.fastq.gz exists but MD5 mismatch, redownloading...
✓ SRR12345678_2.fastq.gz downloaded and verified successfully
⬇ Downloading SRR12345679_1.fastq.gz...
✓ SRR12345679_1.fastq.gz downloaded and verified successfully
✓ Download complete! Samplesheet saved to: samplesheet.csv
```

### Generated Files

**Directory structure:**
```
.
├── fastq/
│   ├── SRR12345678_1.fastq.gz
│   ├── SRR12345678_2.fastq.gz
│   └── SRR12345679.fastq.gz
└── samplesheet.csv
```

**samplesheet.csv format:**
```csv
sample,fastq_1,fastq_2
SRR12345678,fastq/SRR12345678_1.fastq.gz,fastq/SRR12345678_2.fastq.gz
SRR12345679,fastq/SRR12345679.fastq.gz,
```

- **Paired-end reads**: Both `fastq_1` and `fastq_2` columns populated
- **Single-end reads**: Only `fastq_1` populated, `fastq_2` empty
- Paths are relative to the working directory

## SLURM Configuration

The SLURM submission script (`submit_ena_download.sh`) has default resource allocations:

```bash
#SBATCH --time=04:00:00      # 4 hour time limit per download
#SBATCH --cpus-per-task=1    # 1 CPU per task
#SBATCH --mem=2G             # 2GB memory per task
```

### Rate Limiting

**Default:** Maximum 10 concurrent downloads to respect ENA rate limits.

To adjust the concurrency limit, edit `submit_parallel.sh` or submit manually:

```bash
# Allow 20 concurrent downloads (adjust with caution)
sbatch --array=1-100%20 submit_ena_download.sh accessions.txt

# Allow 5 concurrent downloads (more conservative)
sbatch --array=1-100%5 submit_ena_download.sh accessions.txt
```

**To customize other resources**, override at submission:

```bash
sbatch --array=1-10%10 --time=02:00:00 --mem=4G submit_ena_download.sh accessions.txt
```

### Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# View live logs
tail -f logs/ena_download_*.log

# Check for errors
grep -i error logs/ena_download_*.err

# Count completed downloads
ls fastq/*.fastq.gz | wc -l
```

### After Jobs Complete

Once all array tasks finish:
- All FASTQ files will be in the `fastq/` directory
- The `samplesheet.csv` will contain all samples (automatically merged)
- Individual job logs will be in `logs/` directory

## Parallel vs Sequential Execution

| Method | Speed | Use Case |
|--------|-------|----------|
| **Sequential** (`./ena-file-download-read_run-search-fastq_ftp.sh`) | Downloads one file at a time | Small datasets, local testing |
| **SLURM Parallel** (`./submit_parallel.sh`) | All accessions download simultaneously | Large datasets, HPC clusters |

**Example speedup:**
- 50 samples, 2 files each, 10 minutes per file
- Sequential: ~1000 minutes (16+ hours)
- Parallel (10 concurrent): ~100 minutes (1.7 hours)

*Note: Parallel execution limited to 10 concurrent downloads to respect ENA rate limits.*

## How It Works

1. For each accession, the script queries the ENA Portal API to retrieve:
   - FASTQ FTP URLs
   - MD5 checksums

2. For each FASTQ file:
   - **If file exists**: Verifies MD5 checksum
     - **Match**: Skips download
     - **Mismatch**: Deletes and redownloads
   - **If file doesn't exist**: Downloads file

3. After each download, verifies MD5 checksum and reports status

4. Generates a `samplesheet.csv` file with:
   - Sample accession
   - Path to first FASTQ file (or only file for single-end)
   - Path to second FASTQ file (for paired-end) or empty

## Notes

- Files are downloaded to the `fastq/` directory (created automatically)
- For paired-end reads, both files (e.g., `_1.fastq.gz` and `_2.fastq.gz`) are processed
- Failed MD5 verification after download indicates a potential network issue or corrupted transfer
- The `samplesheet.csv` uses relative paths (`fastq/...`) and can be used directly with pipelines like nf-core
