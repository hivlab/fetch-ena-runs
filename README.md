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
- `flock` (for parallel SLURM execution)

## Quick Start

**Sequential mode (local):**
```bash
./ena-file-download-read_run-search-fastq_ftp.sh accessions.txt
```

**Parallel mode (SLURM):**
```bash
./submit_parallel.sh accessions.txt          # 10 parallel jobs (default)
./submit_parallel.sh accessions.txt 20       # 20 parallel jobs
```

## Usage

### Local/Sequential Execution

```bash
./ena-file-download-read_run-search-fastq_ftp.sh <accessions_file>
```

### Parallel Execution on SLURM

For faster downloads on HPC clusters, use the SLURM submission script to process accessions in parallel:

```bash
./submit_parallel.sh <accessions_file> [array_size]
```

This will automatically:
- Count the number of accessions
- Split accessions into N chunks (default: 10)
- Submit a SLURM array job where each task processes multiple accessions
- Download all samples in parallel across compute nodes

**Examples:**
```bash
./submit_parallel.sh accessions.txt     # Split into 10 parallel jobs (default)
./submit_parallel.sh accessions.txt 5   # Split into 5 parallel jobs
./submit_parallel.sh accessions.txt 20  # Split into 20 parallel jobs
```

**Manual SLURM submission:**
```bash
# Submit with 10 parallel jobs (default)
sbatch --array=1-10 submit_ena_download.sh accessions.txt

# Submit with 20 parallel jobs
sbatch --array=1-20 submit_ena_download.sh accessions.txt
```

**Note:** Each array task processes multiple accessions. The script automatically divides the work evenly.

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

1. Create a project directory with an accessions file:
```bash
mkdir my_project
cd my_project

cat > accessions.txt << EOF
SRR12345678
SRR12345679
EOF
```

2. Run the script:

**Option A: Sequential (local machine)**
```bash
# From the project directory
/path/to/ena-file-download-read_run-search-fastq_ftp.sh accessions.txt

# Or from anywhere
/path/to/ena-file-download-read_run-search-fastq_ftp.sh /path/to/my_project/accessions.txt
```

**Option B: Parallel (SLURM cluster)**
```bash
# From anywhere - automatically submits parallel array job
/path/to/submit_parallel.sh /path/to/my_project/accessions.txt

# With custom parallelism (e.g., 20 jobs)
/path/to/submit_parallel.sh /path/to/my_project/accessions.txt 20

# This will:
# - Create logs/ directory in my_project/
# - Split accessions into N chunks (default 10)
# - Submit SLURM array job with N parallel tasks
# - Each task processes its chunk of accessions
```

All outputs will be created in `my_project/` regardless of where you run the script from.

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

**All outputs are created in the same directory as the accessions file:**

**Directory structure:**
```
/path/to/your/project/
├── accessions.txt          # Your input file
├── fastq/                  # Downloaded files
│   ├── SRR12345678_1.fastq.gz
│   ├── SRR12345678_2.fastq.gz
│   └── SRR12345679.fastq.gz
├── samplesheet.csv         # Generated samplesheet
└── logs/                   # SLURM logs (if using parallel mode)
    ├── ena_download_12345_1.log
    └── ena_download_12345_1.err
```

**samplesheet.csv format:**
```csv
sample,fastq_1,fastq_2
SRR12345678,fastq/SRR12345678_1.fastq.gz,fastq/SRR12345678_2.fastq.gz
SRR12345679,fastq/SRR12345679.fastq.gz,
```

- **Paired-end reads**: Both `fastq_1` and `fastq_2` columns populated
- **Single-end reads**: Only `fastq_1` populated, `fastq_2` empty
- **Paths**: Relative paths (`fastq/...`) from the directory containing the accessions file

## SLURM Configuration

The SLURM submission script (`submit_ena_download.sh`) has default resource allocations:

```bash
#SBATCH --time=04:00:00      # 4 hour time limit per download
#SBATCH --cpus-per-task=1    # 1 CPU per task
#SBATCH --mem=2G             # 2GB memory per task
```

### Parallelism Configuration

**Default:** 10 parallel jobs, each processing multiple accessions.

**How it works:**
- 100 accessions with 10 jobs = ~10 accessions per job
- 100 accessions with 20 jobs = ~5 accessions per job

To adjust parallelism:

```bash
# More parallel jobs (faster, but more load on ENA)
./submit_parallel.sh accessions.txt 20

# Fewer parallel jobs (more conservative)
./submit_parallel.sh accessions.txt 5
```

**ENA Rate Limit Considerations:**
- ENA API limit: 50 requests/second
- With 10-20 parallel jobs, you're well within safe limits
- Each job downloads sequentially within its chunk

**To customize resources**, override at submission:

```bash
sbatch --array=1-10%10 --time=02:00:00 --mem=4G submit_ena_download.sh accessions.txt
```

### Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# View live logs (from your project directory where accessions.txt is)
tail -f logs/ena_download_*.log

# Check for errors
grep -i error logs/ena_download_*.err

# Count completed downloads
ls fastq/*.fastq.gz | wc -l
```

**Note:** All outputs (fastq/, samplesheet.csv, logs/) are created in the same directory as your accessions file.

### After Jobs Complete

Once all array tasks finish, all outputs will be in the same directory as your accessions file:
- All FASTQ files in `fastq/` subdirectory
- `samplesheet.csv` with all samples (automatically merged with file locking)
- Individual job logs in `logs/` subdirectory

## Parallel vs Sequential Execution

| Method | Speed | Use Case |
|--------|-------|----------|
| **Sequential** (`./ena-file-download-read_run-search-fastq_ftp.sh`) | One accession at a time | Small datasets, local testing |
| **SLURM Parallel** (`./submit_parallel.sh`) | Multiple accessions in parallel | Large datasets, HPC clusters |

**Example speedup:**
- 100 accessions, 2 files each, 10 minutes per file
- Sequential: ~2000 minutes (33+ hours)
- Parallel (10 jobs): ~200 minutes (3.3 hours)
- Parallel (20 jobs): ~100 minutes (1.7 hours)

**How parallelism works:**
- Accessions are split into N chunks (you choose N)
- Each SLURM job processes one chunk sequentially
- All N jobs run in parallel

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
