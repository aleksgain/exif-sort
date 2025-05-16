# EXIF-based Photo and Video Organizer

A set of bash scripts for organizing photos and videos based on their EXIF creation date. These scripts are particularly useful for Synology NAS users who want to maintain a clean and organized photo/video library.

## Features

- Organizes files based on EXIF creation date
- Maintains Synology thumbnail structure (@eaDir)
- Handles both photos and videos separately
- Optional: Moves small files (<300px) to a DELETE folder
- Preserves file timestamps based on EXIF data
- Supports dry run mode for previewing changes
- Configurable logging with verbosity levels
- Ignores specified directories (e.g., "Edited Photos")

## Prerequisites

- ExifTool installed and accessible
- Bash shell environment
- Appropriate permissions to read/write in target directories

## Installation

1. Clone this repository:
```bash
git clone https://github.com/aleksgain/exif-sort.git
cd exif-sort
```

2. Make the scripts executable:
```bash
chmod +x exif_photo.sh exif_video.sh
```

3. Edit the configuration section in each script to match your environment:
   - `source_dir`: Base directory to scan
   - `dest_dir`: Destination directory
   - `delete_dir`: Directory for small files
   - `exiftool_path`: Path to ExifTool
   - `ignore_dir`: Directory to ignore

## Usage

### Photo Organization

```bash
# Basic usage
./exif_photo.sh

# Dry run (preview changes)
./exif_photo.sh --dry-run

# Verbose logging
./exif_photo.sh --verbose

# Skip moving small files to DELETE folder
./exif_photo.sh --no-delete

# Custom log file location
./exif_photo.sh --log-file /path/to/custom.log

# Combine options
./exif_photo.sh --dry-run --verbose --no-delete --log-file /path/to/custom.log
```

### Video Organization

```bash
# Basic usage
./exif_video.sh

# Dry run (preview changes)
./exif_video.sh --dry-run

# Verbose logging
./exif_video.sh --verbose

# Skip moving small files to DELETE folder
./exif_video.sh --no-delete

# Custom log file location
./exif_video.sh --log-file /path/to/custom.log

# Combine options
./exif_video.sh --dry-run --verbose --no-delete --log-file /path/to/custom.log
```

## Supported File Types

### Photos
- GIF, HEIC, RW2, DNG, HEIF, JPEG, JPG, ORF, PNG, RAW, TIF, TIFF, NEF, CR2, CR3, ARW, RAF, SR2, SRW

### Videos
- AVI, MOV, MP4, MKV, FLV, WMV, HEVC, WEBM

## Features in Detail

### EXIF Date Handling
- Extracts creation date from EXIF data
- Validates dates for sanity (not in future, not too old)
- Creates year/month/day directory structure
- Adjusts file timestamps to match EXIF data

### Synology Integration
- Preserves @eaDir thumbnail structure
- Moves thumbnails along with their parent files
- Maintains compatibility with Synology Photo Station/Photos

### Small File Detection
- Checks image/video dimensions
- Optionally moves files smaller than 300px to DELETE folder (can be disabled with --no-delete)
- Preserves associated thumbnails

### Logging
- Default: Shows only important operations and summary
- Verbose: Shows all operations and details
- Custom log file location support
- Summary statistics at the end of each run

## Example Directory Structure

```
/volume1/photo/
├── Photo/
│   ├── 2024/
│   │   ├── 01/
│   │   │   ├── 15/
│   │   │   │   ├── IMG_001.jpg
│   │   │   │   └── @eaDir/
│   │   │   └── 16/
│   │   └── 02/
│   └── Edited Photos/
├── Video/
│   ├── 2024/
│   │   ├── 01/
│   │   │   └── 15/
│   │   └── 02/
│   └── Edited Videos/
└── DELETE/
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- ExifTool for providing the EXIF data extraction capabilities
- Synology for their photo management system 
