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

```bash
./ena-file-download-read_run-search-fastq_ftp-20260212-1456.sh <accessions_file>
```

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
./ena-file-download-read_run-search-fastq_ftp-20260212-1456.sh accessions.txt
```

## Output

The script will download FASTQ files to the current directory with status messages:

```
✓ SRR12345678_1.fastq.gz already exists with correct MD5 sum, skipping
✗ SRR12345678_2.fastq.gz exists but MD5 mismatch, redownloading...
✓ SRR12345678_2.fastq.gz downloaded and verified successfully
⬇ Downloading SRR12345679_1.fastq.gz...
✓ SRR12345679_1.fastq.gz downloaded and verified successfully
```

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

## Notes

- Files are downloaded to the current working directory
- For paired-end reads, both files (e.g., `_1.fastq.gz` and `_2.fastq.gz`) are processed
- Failed MD5 verification after download indicates a potential network issue or corrupted transfer
