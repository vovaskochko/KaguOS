#!/bin/bash

# Expected input: <file to copy> <disk name> <start1> <end1> [<start2> <end2> ...]
if [[ $# -lt 4 || $(( ($# - 2) % 2 )) -ne 0 ]]; then
    echo "Usage: $0 <file to copy> <disk name> <start1> <end1> [<start2> <end2> ...]"
    exit 1
fi

FILE_TO_COPY="$1"
DISK_NAME="hw/$2"  # Prefix disk name with hw/
shift 2  # Shift arguments to leave only the start-end pairs

# Validate that all start-end pairs are numbers and ordered correctly
INTERVALS=("$@")
for ((i = 0; i < ${#INTERVALS[@]}; i += 2)); do
    START="${INTERVALS[i]}"
    END="${INTERVALS[i+1]}"
    
    if ! [[ "$START" =~ ^[0-9]+$ && "$END" =~ ^[0-9]+$ && "$START" -lt "$END" ]]; then
        echo -e "\033[91m[ERROR] Invalid start-end pair ($START, $END). Ensure start < end and both are numeric.\033[0m"
        exit 1
    fi
done

# Check if both files exist
if [[ ! -f "$FILE_TO_COPY" ]]; then
    echo -e "\033[91m[ERROR] User program file '$FILE_TO_COPY' does not exist.\033[0m"
    exit 1
fi

if [[ ! -f "$DISK_NAME" ]]; then
    echo -e "\033[91m[ERROR] Disk file '$DISK_NAME' does not exist.\033[0m"
    exit 1
fi

# Count total lines in user program
TOTAL_LINES=$(wc -l < "$FILE_TO_COPY")

# Calculate total available slots in the given INTERVALS
AVAILABLE_SLOTS=0
for ((i = 0; i < ${#INTERVALS[@]}; i += 2)); do
    START="${INTERVALS[i]}"
    END="${INTERVALS[i+1]}"
    AVAILABLE_SLOTS=$((AVAILABLE_SLOTS + (END - START + 1)))
done

# Check if the fragmented space is sufficient
if [[ "$TOTAL_LINES" -gt "$AVAILABLE_SLOTS" ]]; then
    echo -e "\033[91m[ERROR] Not enough space in the specified INTERVALS. Need $TOTAL_LINES lines, but available slots are only $AVAILABLE_SLOTS.\033[0m"
    exit 1
fi

# Fill all specified INTERVALS with empty lines first
for ((i = 0; i < ${#INTERVALS[@]}; i += 2)); do
    START="${INTERVALS[i]}"
    END="${INTERVALS[i+1]}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "${START},${END}s/.*//" "$DISK_NAME"
    else
        sed -i "${START},${END}s/.*//" "$DISK_NAME"
    fi
done

# Replace lines in the given INTERVALS with the user program content
LINE_NO=0
while IFS= read -r LINE && [[ "$LINE_NO" -lt "$TOTAL_LINES" ]]; do
    for ((i = 0; i < ${#INTERVALS[@]}; i += 2)); do
        START="${INTERVALS[i]}"
        END="${INTERVALS[i+1]}"
        
        for ((POS = START; POS <= END && LINE_NO < TOTAL_LINES; POS++)); do
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "${POS}s|.*|${LINE}|" "$DISK_NAME"
            else
                sed -i "${POS}s|.*|${LINE}|" "$DISK_NAME"
            fi
            ((LINE_NO++))
            IFS= read -r LINE || break  # Read next line if available
        done

        # Stop if we have written all program lines
        if [[ "$LINE_NO" -ge "$TOTAL_LINES" ]]; then
            break 2
        fi
    done
done < "$FILE_TO_COPY"

echo -e "\033[92m[INFO] Successfully copied $LINE_NO lines from $FILE_TO_COPY to $DISK_NAME using fragmented intervals.\033[0m"
