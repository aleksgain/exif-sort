#!/bin/bash

# Configuration
source_dir="/volume1/photo/Video"     # Base directory to scan
dest_dir="/volume1/photo/Video"       # Destination directory for videos
delete_dir="/volume1/photo/DELETE"    # Directory for small videos
exiftool_path="/usr/share/applications/ExifTool/exiftool"  # Path to ExifTool
log_file="/var/services/homes/username/scripts/logs/exif_video_$(date +%Y%m%d_%H%M%S).log"  # Default log file location
ignore_dir="/volume1/photo/Video/Ignore"  # Directory to ignore

# Parse command line arguments
dry_run=false
verbose=false
move_small_files=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            dry_run=true
            shift
            ;;
        --verbose)
            verbose=true
            shift
            ;;
        --no-delete)
            move_small_files=false
            shift
            ;;
        --log-file)
            if [ -z "$2" ]; then
                echo "Error: --log-file requires a path"
                echo "Usage: $0 [--dry-run] [--verbose] [--no-delete] [--log-file /path/to/logfile]"
                exit 1
            fi
            log_file="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--verbose] [--no-delete] [--log-file /path/to/logfile]"
            exit 1
            ;;
    esac
done

# Initialize counters
total_files=0
moved_files=0
skipped_files=0
deleted_files=0
error_files=0

# Function to log messages
log_message() {
    local message=$1
    local force_log=${2:-false}  # Second parameter to force logging even in dry run
    local is_error=${3:-false}   # Third parameter to indicate if this is an error message
    
    if [ "$dry_run" = false ] || [ "$force_log" = true ]; then
        if [ "$verbose" = true ] || [ "$force_log" = true ] || [ "$is_error" = true ]; then
            echo "$message" | tee -a "$log_file"
        fi
    fi
}

# Function to check if a date is within sanity bounds (not in the future and not too old)
is_date_sane() {
    local date_str=$1
    local current_year=$(date +%Y)
    local min_year=$((current_year - 100))
    local year=${date_str:0:4}
    
    # Check if year is between min_year and current_year
    if [ "$year" -ge "$min_year" ] && [ "$year" -le "$current_year" ]; then
        return 0  # Date is sane
    else
        return 1  # Date is outside bounds
    fi
}

# Function to check video dimensions
check_video_dimensions() {
    local file_path=$1
    local dimensions=$("$exiftool_path" -ImageWidth -ImageHeight "$file_path" 2>/dev/null)
    local width=$(echo "$dimensions" | grep "Image Width" | awk '{print $4}')
    local height=$(echo "$dimensions" | grep "Image Height" | awk '{print $4}')
    
    # If we couldn't get dimensions, return 0 (not small)
    if [ -z "$width" ] || [ -z "$height" ]; then
        return 0
    fi
    
    # Check if either dimension is less than 300
    if [ "$width" -lt 300 ] || [ "$height" -lt 300 ]; then
        return 1  # Video is too small
    else
        return 0  # Video is large enough
    fi
}

# Function to extract the year, month, and day from EXIF data
get_exif_date() {
    file_path=$1
    file_name=$(basename "$file_path")

    # Try to get date from EXIF data
    exif_date=$("$exiftool_path" -CreateDate -d "%Y/%m/%d" "$file_path" 2>/dev/null | grep "Create Date" | awk '{print $4}')
    
    if [ ! -z "$exif_date" ]; then
        # Check if the date is within sanity bounds
        if is_date_sane "$exif_date"; then
            echo "$exif_date/$file_name"
            return 0
        else
            echo "Date out of bounds: $exif_date"
            return 1
        fi
    else
        return 1  # No EXIF date available
    fi
}

# Function to check if a file is already in the correct location
is_in_correct_location() {
    local file_path=$1
    local current_path=$(dirname "$file_path")
    local file_name=$(basename "$file_path")
    
    # Get the expected path based on EXIF
    local expected_path=$(get_exif_date "$file_path")
    if [ $? -ne 0 ]; then
        return 0  # If we can't get EXIF date, consider it in correct location
    fi
    
    # Extract the date part from the expected path
    local expected_date_path=$(dirname "$expected_path")
    
    # Check if the current path contains the expected date path
    if [[ "$current_path" == *"$expected_date_path"* ]]; then
        return 0  # File is in correct location
    else
        return 1  # File needs to be moved
    fi
}

# Function to perform or simulate file operations
perform_operation() {
    local operation=$1
    local source=$2
    local destination=$3
    local message=$4

    if [ "$dry_run" = true ]; then
        echo "[DRY RUN] Would $operation: $source -> $destination"
    else
        if [ "$operation" = "move" ]; then
            mv "$source" "$destination"
            # Adjust file timestamp based on EXIF data
            exif_date=$("$exiftool_path" -CreateDate -d "%Y:%m:%d %H:%M:%S" "$destination" 2>/dev/null | grep "Create Date" | awk '{print $4}')
            if [ ! -z "$exif_date" ]; then
                touch -d "$exif_date" "$destination"
                log_message "Adjusted file timestamp to EXIF date: $exif_date" false false
            fi
        elif [ "$operation" = "mkdir" ]; then
            mkdir -p "$destination"
        fi
        log_message "$message" false false
    fi
}

# Function to handle Synology thumbnails
handle_thumbnails() {
    local file_path=$1
    local dest_path=$2
    local file_dir=$(dirname "$file_path")
    local file_name=$(basename "$file_path")
    local ea_dir="$file_dir/@eaDir/$file_name"
    local dest_ea_dir="$(dirname "$dest_path")/@eaDir/$(basename "$dest_path")"

    # Check if @eaDir exists for this file
    if [ -d "$ea_dir" ]; then
        # Create destination @eaDir if it doesn't exist
        perform_operation "mkdir" "" "$dest_ea_dir" "Created thumbnail directory: $dest_ea_dir"
        
        # Move all thumbnail files
        if [ -d "$ea_dir" ]; then
            for thumb in "$ea_dir"/*; do
                if [ -f "$thumb" ]; then
                    local thumb_name=$(basename "$thumb")
                    perform_operation "move" "$thumb" "$dest_ea_dir/$thumb_name" "Moved thumbnail: $thumb -> $dest_ea_dir/$thumb_name"
                fi
            done
        fi
    fi
}

# Array of allowed video extensions
allowed_extensions=("avi" "mov" "mp4" "mkv" "flv" "wmv" "hevc" "webm")

# Check if exiftool exists at the specified path
if [ ! -x "$exiftool_path" ]; then
    echo "Error: ExifTool not found at $exiftool_path"
    echo "Please check the exiftool_path configuration in the script"
    exit 1
fi

# Create log file with timestamp (only if not specified by user)
if [ "$log_file" = "/var/services/homes/aleksgain/scripts/exif_video_$(date +%Y%m%d_%H%M%S).log" ]; then
    log_file="/var/services/homes/aleksgain/scripts/exif_video_$(date +%Y%m%d_%H%M%S).log"
fi
log_message "Starting EXIF video resort process at $(date)" true false
if [ "$dry_run" = true ]; then
    log_message "Running in DRY RUN mode - no files will be moved" true false
fi

# Create DELETE directory if it doesn't exist and moving small files is enabled
if [ "$dry_run" = false ] && [ "$move_small_files" = true ]; then
    mkdir -p "$delete_dir"
fi

# Iterate through all files in the source directory
find "$source_dir" -type f -print0 | while IFS= read -r -d '' file; do
    ((total_files++))
    
    # Skip files in @eaDir directories
    if [[ "$file" == *"@eaDir"* ]]; then
        continue
    fi
    
    # Skip files in ignore directory
    if [[ "$file" == *"$ignore_dir"* ]]; then
        log_message "Skipped $file (in ignore directory)" false false
        ((skipped_files++))
        continue
    fi
    
    # Get the file extension
    file_extension=${file##*.}
    file_extension=${file_extension,,}  # Convert to lowercase

    # Check if the file extension is allowed
    if [[ "${allowed_extensions[*]}" =~ "$file_extension" ]]; then
        # Check video dimensions for small videos
        if check_video_dimensions "$file"; then
            # Video is large enough, proceed with normal sorting
            if ! is_in_correct_location "$file"; then
                # Extract the date and destination path for each file
                dest_path=$(get_exif_date "$file")
                if [ $? -eq 0 ]; then
                    dest_path="$dest_dir/$dest_path"

                    # Create the subdirectories in the destination directory if they don't exist
                    perform_operation "mkdir" "" "$(dirname "$dest_path")" "Created directory: $(dirname "$dest_path")"

                    # Move the file to the destination directory
                    perform_operation "move" "$file" "$dest_path" "Moved $file to $dest_path"
                    ((moved_files++))
                    
                    # Handle associated thumbnails
                    handle_thumbnails "$file" "$dest_path"
                else
                    log_message "Skipped $file (no valid EXIF date)" false false
                    ((skipped_files++))
                fi
            else
                log_message "Skipped $file (already in correct location)" false false
                ((skipped_files++))
            fi
        else
            if [ "$move_small_files" = true ]; then
                # Video is too small, move to DELETE folder
                delete_path="$delete_dir/$(basename "$file")"
                perform_operation "move" "$file" "$delete_path" "Moved small video $file to $delete_path"
                ((deleted_files++))
                
                # Handle associated thumbnails for deleted files
                handle_thumbnails "$file" "$delete_path"
            else
                log_message "Skipped $file (small video, delete disabled)" false false
                ((skipped_files++))
            fi
        fi
    else
        log_message "Skipped $file (unsupported file type)" false false
        ((skipped_files++))
    fi
done

# Print summary
log_message "=== Summary ===" true false
log_message "Total files processed: $total_files" true false
log_message "Files moved: $moved_files" true false
log_message "Files skipped: $skipped_files" true false
log_message "Files moved to DELETE: $deleted_files" true false
log_message "Files with errors: $error_files" true false
log_message "Completed EXIF video resort process at $(date)" true false
if [ "$dry_run" = true ]; then
    log_message "This was a DRY RUN - no files were actually moved" true false
fi 
