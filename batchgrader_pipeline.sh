#!/bin/bash

# =====================================================================================
# Homework 7 - Batch Autograder
# Author: Dr. Bhargav Bhatkalkar, KFSCIS, Florida International University  
# Description: This script processes all student submissions and generates grade files
# =====================================================================================

echo "=========================================================================="
echo "                  HOMEWORK-7: Batch Autograder                            "
echo "=========================================================================="
echo "Date: $(date)"
echo

# Check if autograder script exists
if [ ! -f "autograder_pipeline.sh" ]; then
    echo "ERROR: autograder_pipeline.sh not found in current directory!"
    echo "Please place the autograder script in the same directory as this batch script."
    echo "---------------------------------------------------------"
    echo " "
    exit 1
fi

# Check if required framework files exist
REQUIRED_FILES=("pipeline_driver.c" "pipeline.h")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Required framework file '$file' not found!"
        echo "Please ensure all framework files are in the current directory."
        echo "---------------------------------------------------------"
        echo " "
        exit 1
    fi
done

# Make autograder script executable
chmod +x autograder_pipeline.sh

# Remove existing results directory if it exists for clean startup
if [ -d "$RESULTS_DIR" ]; then
    echo "Removing existing results directory for clean startup..."
    rm -rf "$RESULTS_DIR"
fi

# Create results directory (clean startup)
RESULTS_DIR="GRADING_RESULTS"

if [ -d "$RESULTS_DIR" ]; then
    echo "Removing existing results directory for clean startup..."
    rm -rf "$RESULTS_DIR"
fi

mkdir -p "$RESULTS_DIR"

# Create summary file
SUMMARY_FILE="$RESULTS_DIR/GRADING_SUMMARY.txt"
echo "COP4610 Homework 7 - Grading Summary" > "$SUMMARY_FILE"
echo "Generated: $(date)" >> "$SUMMARY_FILE"
echo "=================================================================" >> "$SUMMARY_FILE"
echo >> "$SUMMARY_FILE"

# Create detailed log file
LOG_FILE="$RESULTS_DIR/batch_grading.log"
echo "Batch Grading Log - $(date)" > "$LOG_FILE"
echo "=================================" >> "$LOG_FILE"
echo >> "$LOG_FILE"

# Master CSV file
MASTER_CSV="$RESULTS_DIR/ALL_GRADES.csv"
echo "zip_filename,final_score" > "$MASTER_CSV"

# Initialize counters
TOTAL_STUDENTS=0
SUCCESSFUL_GRADES=0
FAILED_GRADES=0
PERFECT_SCORES=0

# Required files for the assignment
REQUIRED_C_FILES=("pipeline.c")

# Function to log messages
log_message() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to extract student name from filename
extract_student_name() {
    local filename="$1"
    local base_name=$(basename "$filename" .zip)
    if [[ "$base_name" =~ ^A[0-9]+_(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" | tr '_' ' '
    elif [[ "$base_name" =~ ^([A-Za-z]+[_\s]+[A-Za-z]+) ]]; then
        echo "${BASH_REMATCH[1]}" | tr '_' ' '
    elif [[ "$base_name" =~ ^([A-Za-z]+_[A-Za-z]+) ]]; then
        echo "${BASH_REMATCH[1]}" | tr '_' ' '
    else
        echo "$base_name" | tr '_' ' ' | sed 's/[^A-Za-z0-9 ]//g'
    fi
}

# Function to create clean filename
create_clean_name() {
    local name="$1"
    echo "$name" | tr ' ' '_' | tr -cd '[:alnum:]_-'
}

# Process ZIPs
shopt -s nullglob
zip_files=(*.zip)

if [ ${#zip_files[@]} -eq 0 ]; then
    echo "No ZIP files found in current directory"
    exit 1
fi

log_message "Found ${#zip_files[@]} student submission(s) to process"
log_message ""

# Process each student
for zip_file in "${zip_files[@]}"; do
    TOTAL_STUDENTS=$((TOTAL_STUDENTS + 1))

    STUDENT_NAME=$(extract_student_name "$zip_file")
    CLEAN_NAME=$(create_clean_name "$STUDENT_NAME")
    if [[ -z "$STUDENT_NAME" || "$STUDENT_NAME" =~ ^[[:space:]]*$ ]]; then
        STUDENT_NAME=$(basename "$zip_file" .zip)
        CLEAN_NAME=$(create_clean_name "$STUDENT_NAME")
    fi
    
    echo "----------------------------------------------------------"
    log_message "Processing: $STUDENT_NAME ($zip_file)"

    TEMP_DIR="temp_${CLEAN_NAME}_$"
    mkdir -p "$TEMP_DIR"

    if ! unzip -q "$zip_file" -d "$TEMP_DIR" 2>/dev/null; then
        log_message "  ERROR: Failed to extract $zip_file"
        echo "$STUDENT_NAME: EXTRACTION_FAILED" >> "$SUMMARY_FILE"
        FAILED_GRADES=$((FAILED_GRADES + 1))
        rm -rf "$TEMP_DIR"
        echo "---------------------------------------------------------"
        echo " "
        continue
    fi

    log_message "  Required files for this assignment:"
    for required_file in "${REQUIRED_C_FILES[@]}"; do
        log_message "    - $required_file"
    done
    log_message "    - README.txt (required)"

    FOUND_FILES=()
    MISSING_FILES=()

    log_message "  File submission status:"
    for required_file in "${REQUIRED_C_FILES[@]}"; do
        found_file=$(find "$TEMP_DIR" -name "$required_file" -type f ! -path "*/__MACOSX/*" | head -1)
        if [ -n "$found_file" ]; then
            FOUND_FILES+=("$required_file:$found_file")
            log_message "    ✅ Found: $required_file"
        else
            MISSING_FILES+=("$required_file")
            log_message "    ❌ Missing: $required_file"
        fi
    done   

    # Check for README file with flexible case-insensitive matching
    README_FOUND=false
    README_FILE_FOUND=""

    # Find any file with "readme" in name (case-insensitive)
    readme_candidates=$(find "$TEMP_DIR" -type f -iname "*readme*" ! -path "*/__MACOSX/*" 2>/dev/null)
    
    if [ -n "$readme_candidates" ]; then
        # Priority: PDF > DOCX > TXT > MD > No extension
        
        # Try PDF first
        found_readme=$(echo "$readme_candidates" | grep -i '\.pdf' | head -1)
        
        # Try DOCX
        if [ -z "$found_readme" ]; then
            found_readme=$(echo "$readme_candidates" | grep -i '\.docx' | head -1)
        fi
        
        # Try TXT
        if [ -z "$found_readme" ]; then
            found_readme=$(echo "$readme_candidates" | grep -i '\.txt' | head -1)
        fi
        
        # Try MD
        if [ -z "$found_readme" ]; then
            found_readme=$(echo "$readme_candidates" | grep -i '\.md' | head -1)
        fi
        
        # Try no extension (README, readme)
        if [ -z "$found_readme" ]; then
            found_readme=$(echo "$readme_candidates" | grep -iE '/readme' | head -1)
        fi
        
        if [ -n "$found_readme" ]; then
            README_FOUND=true
            README_FILE_FOUND="$found_readme"
            log_message "    ✅ Found README: $(basename "$README_FILE_FOUND")"
        fi
    fi
    
    if [ "$README_FOUND" = false ]; then
        log_message "  ❌ ERROR: Missing README file"
        echo "$STUDENT_NAME: MISSING_README - No README file found" >> "$SUMMARY_FILE"
        FAILED_GRADES=$((FAILED_GRADES + 1))
        rm -rf "$TEMP_DIR"
        echo "---------------------------------------------------------"
        echo " "
        continue
    fi

    SHOULD_GRADE=true

    if [ ${#FOUND_FILES[@]} -eq 0 ]; then
        log_message "  ⚠️ ERROR: No submission of \"pipeline.c\" found"
        echo "$STUDENT_NAME: NO_C_FILES" >> "$SUMMARY_FILE"
        FAILED_GRADES=$((FAILED_GRADES + 1))
        SHOULD_GRADE=false
        echo "---------------------------------------------------------"
        echo " "
    fi

    if [ "$SHOULD_GRADE" = true ] && [ "$README_FOUND" = false ]; then
        log_message "  ⚠️ ERROR: No README file submitted"
        echo "$STUDENT_NAME: NO_README" >> "$SUMMARY_FILE"
        FAILED_GRADES=$((FAILED_GRADES + 1))
        SHOULD_GRADE=false
        echo "---------------------------------------------------------"
        echo " "
    fi

    if [ "$SHOULD_GRADE" = true ]; then
        if command -v make >/dev/null 2>&1; then make clean 2>/dev/null || true; fi
        rm -f pipeline *.o 2>/dev/null
        rm -rf Results/ 2>/dev/null

        for file_info in "${FOUND_FILES[@]}"; do
            file_name=$(echo "$file_info" | cut -d':' -f1)
            file_path=$(echo "$file_info" | cut -d':' -f2-)
            cp "$file_path" "./$file_name" || {
                log_message "  ERROR: Failed to copy $file_name"
                echo "$STUDENT_NAME: COPY_FAILED" >> "$SUMMARY_FILE"
                FAILED_GRADES=$((FAILED_GRADES + 1))
                SHOULD_GRADE=false
                echo "---------------------------------------------------------"
                
                break
            }
        done
    fi

    if [ "$SHOULD_GRADE" = true ]; then
        GRADE_FILE="$RESULTS_DIR/${CLEAN_NAME}_Grade.txt"
        export STUDENT_ZIP_NAME="$(basename "$zip_file" .zip)"

        log_message "  Running autograder for $STUDENT_ZIP_NAME..."
        {
            echo "=========================================================================="
            echo "                   GRADE REPORT FOR: $STUDENT_NAME"
            echo "=========================================================================="
            echo "Submission File: $zip_file"
            echo "Graded on: $(date)"
            echo "Graded by: Assignment Autograder"
            echo
        } > "$GRADE_FILE"

        AUTOGRADER_OUTPUT=$(timeout 60 ./autograder_pipeline.sh 2>&1)
        AUTOGRADER_EXIT_CODE=$?
        echo "$AUTOGRADER_OUTPUT" >> "$GRADE_FILE"

        if [ $AUTOGRADER_EXIT_CODE -eq 0 ]; then
            ORIGINAL_SCORE=$(echo "$AUTOGRADER_OUTPUT" | grep "FINAL GRADE:" | grep -o '[0-9]\+/[0-9]\+' | cut -d'/' -f1)
            ORIGINAL_TOTAL=$(echo "$AUTOGRADER_OUTPUT" | grep "FINAL GRADE:" | grep -o '[0-9]\+/[0-9]\+' | cut -d'/' -f2)
            if [ -n "$ORIGINAL_SCORE" ] && [ -n "$ORIGINAL_TOTAL" ]; then
                FINAL_SCORE=$ORIGINAL_SCORE
                PERCENTAGE=$(( FINAL_SCORE * 100 / ORIGINAL_TOTAL ))
                echo "$STUDENT_NAME: $FINAL_SCORE/$ORIGINAL_TOTAL" >> "$SUMMARY_FILE"
				log_message "  Score: $FINAL_SCORE/$ORIGINAL_TOTAL"               
                [ "$FINAL_SCORE" -eq 100 ] && PERFECT_SCORES=$((PERFECT_SCORES + 1))
                if [ -f "Results/grade.csv" ]; then
                    while IFS=',' read -r zip_name assignment_name original_score; do
                        if [[ "$original_score" != "final_score" ]]; then
                            echo "$zip_name,$original_score" >> "$MASTER_CSV"
                        fi
                    done < "Results/grade.csv"
                fi
            fi
            SUCCESSFUL_GRADES=$((SUCCESSFUL_GRADES + 1))
        elif [ $AUTOGRADER_EXIT_CODE -eq 124 ]; then
            log_message "  ERROR: Autograder timed out"
            echo "$STUDENT_NAME: TIMEOUT" >> "$SUMMARY_FILE"
            FAILED_GRADES=$((FAILED_GRADES + 1))
            echo "---------------------------------------------------------"
            
        else
            log_message "  ⚠️ ERROR: Autograder failed (exit code: $AUTOGRADER_EXIT_CODE)"
            echo "$STUDENT_NAME: AUTOGRADER_FAILED" >> "$SUMMARY_FILE"
            FAILED_GRADES=$((FAILED_GRADES + 1))
            echo "---------------------------------------------------------"
            
        fi

        if [ -d "Results" ]; then
            STUDENT_RESULTS_DIR="$RESULTS_DIR/${CLEAN_NAME}_Results"
            mkdir -p "$STUDENT_RESULTS_DIR"
            cp -r Results/* "$STUDENT_RESULTS_DIR/" 2>/dev/null || true
        fi
    fi

    chmod -R 755 "$TEMP_DIR" 2>/dev/null || true
    rm -rf "$TEMP_DIR"
    for file in "${REQUIRED_C_FILES[@]}"; do rm -f "$file" 2>/dev/null; done
    rm -f pipeline *.o 2>/dev/null
    rm -rf Results/ 2>/dev/null
    unset STUDENT_ZIP_NAME
    log_message ""
done

# Summary
echo >> "$SUMMARY_FILE"
echo "=================================================================" >> "$SUMMARY_FILE"
echo "                        GRADING STATISTICS" >> "$SUMMARY_FILE"
echo "=================================================================" >> "$SUMMARY_FILE"
echo "Total Students Processed: $TOTAL_STUDENTS" >> "$SUMMARY_FILE"
echo "Successfully Graded: $SUCCESSFUL_GRADES" >> "$SUMMARY_FILE"
echo "Failed to Grade: $FAILED_GRADES" >> "$SUMMARY_FILE"
echo "Perfect Scores (90/90): $PERFECT_SCORES" >> "$SUMMARY_FILE"

if [ $TOTAL_STUDENTS -gt 0 ]; then
    echo "Success Rate: $(( SUCCESSFUL_GRADES * 100 / TOTAL_STUDENTS ))%" >> "$SUMMARY_FILE"
fi

echo >> "$SUMMARY_FILE"
echo "Individual grade files are in: $RESULTS_DIR/" >> "$SUMMARY_FILE"
echo "Master CSV file: $MASTER_CSV" >> "$SUMMARY_FILE"
echo "Detailed log file: $LOG_FILE" >> "$SUMMARY_FILE"

echo "=========================================================================="
echo "                      BATCH GRADING COMPLETE"
echo "=========================================================================="
echo "Total Students Processed: $TOTAL_STUDENTS"
echo "Successfully Graded: $SUCCESSFUL_GRADES"
echo "Failed to Grade: $FAILED_GRADES"
echo "Perfect Scores: $PERFECT_SCORES"
[ $TOTAL_STUDENTS -gt 0 ] && echo "Success Rate: $(( SUCCESSFUL_GRADES * 100 / TOTAL_STUDENTS ))%"
echo "Results Directory: $RESULTS_DIR/"
echo "Summary File: $SUMMARY_FILE"
echo "Master CSV: $MASTER_CSV"
echo "Detailed Log: $LOG_FILE"
echo "=========================================================================="