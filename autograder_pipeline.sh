#!/bin/bash

# =============================================================================
# ASSIGNMENT SETTINGS (Edit these for each assignment)
# =============================================================================
ASSIGNMENT_NAME="Multi-Threaded Number Processing Pipeline"
TOTAL_POINTS=90

# Test case weights (must sum to exactly 90)
declare -A TEST_WEIGHTS=(
    ["1"]=25    # Test 1 worth 25 points 
    ["2"]=25    # Test 2 worth 25 points 
    ["3"]=25    # Test 3 worth 25 points 
)

# Synchronization test weights
DEADLOCK_POINTS=8
RACE_CONDITION_POINTS=7

TIMEOUT_SECONDS=10

# Function to find makefile with case-insensitive matching
find_makefile() {
    local makefile_path=""
    
    # Try exact matches first (preferred)
    if [[ -f "Makefile" ]]; then
        makefile_path="Makefile"
    elif [[ -f "makefile" ]]; then
        makefile_path="makefile"
    else
        makefile_path="" 
    fi
    
    echo "$makefile_path"
}

# =============================================================================
# FILE SETTINGS
# =============================================================================
EXECUTABLE_NAME="pipeline"

# =============================================================================
# COLORS FOR OUTPUT
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Disable colors if output is redirected
if [[ ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# =============================================================================
# INITIALIZE SCORES
# =============================================================================
TOTAL_TESTS=0
declare -a TEST_SCORES  # Array to store individual test scores
DEADLOCK_SCORE=0
RACE_CONDITION_SCORE=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

print_partial() {
    echo -e "${YELLOW}⚡ $1${NC}"
}

# Function to calculate proportional score for a test case
calculate_proportional_score() {
    local test_num=$1
    local expected_file=$2
    local student_output=$3
    local crashed=$4
    
    # If program crashed, return 0
    if [[ $crashed -eq 1 ]]; then
        echo "0"
        return
    fi
    
    # If files don't exist, return 0
    if [[ ! -f "$expected_file" || ! -f "$student_output" ]]; then
        echo "0"
        return
    fi
    
    # Check if outputs are identical (full credit)
    if diff -w -B "$expected_file" "$student_output" > /dev/null 2>&1; then
        echo "1.0"
        return
    fi
    
    # Calculate proportional score based on line matching
    local expected_content=""
    local student_content=""
    
    if [[ -f "$expected_file" ]]; then
        expected_content=$(cat "$expected_file")
    fi
    
    if [[ -f "$student_output" ]]; then
        student_content=$(cat "$student_output")
    fi
    
    # If student produced no output, return 0
    if [[ -z "$student_content" ]]; then
        echo "0"
        return
    fi
    
    # Convert to arrays for line-by-line comparison
    local -a expected_lines
    local -a student_lines
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            expected_lines+=("$(echo "$line" | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
        fi
    done <<< "$expected_content"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            student_lines+=("$(echo "$line" | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")
        fi
    done <<< "$student_content"
    
    # Line-by-line comparison
    local total_lines=${#expected_lines[@]}
    local correct_lines=0
    
    if [[ $total_lines -eq 0 ]]; then
        echo "0"
        return
    fi
    
    for ((i=0; i<total_lines; i++)); do
        if [[ i -lt ${#student_lines[@]} && "${expected_lines[i]}" == "${student_lines[i]}" ]]; then
            ((correct_lines++))
        fi
    done
    
    # Penalize extra lines in student output
    if [[ ${#student_lines[@]} -gt $total_lines ]]; then
        local penalty=$(( ${#student_lines[@]} - total_lines ))
        correct_lines=$(( correct_lines > penalty ? correct_lines - penalty : 0 ))
    fi
    
    # Calculate percentage
    local score=0
    if [[ $total_lines -gt 0 ]]; then
        score=$(echo "scale=3; $correct_lines / $total_lines" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Cap at 1.0
    local max_check=$(echo "$score > 1.0" | bc -l 2>/dev/null || echo "0")
    if [[ $max_check -eq 1 ]]; then
        score="1.0"
    fi
    
    echo "$score"
}

# Show output differences
show_section_differences() {
    local test_num=$1
    local expected_file=$2
    local student_output=$3
    local score=$4
    local test_weight=$5
    
    # Show score earned first
    local points_earned=$(echo "scale=1; $score * $test_weight" | bc -l 2>/dev/null || echo "0")
    local percentage=$(echo "scale=0; ($score * 100 + 0.5) / 1" | bc -l 2>/dev/null || echo "0")
    echo -e "${YELLOW}   Points Earned: ${points_earned}/${test_weight} (${percentage}%)${NC}"
    
    # Apply whitespace normalization for display
    local expected_data=""
    local student_data=""
    
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$line" ]]; then
            expected_data+="$line"$'\n'
        fi
    done < "$expected_file"
    
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$line" ]]; then
            student_data+="$line"$'\n'
        fi
    done < "$student_output"
    
    echo "   ❌ Output mismatch for Test $test_num"
    
    local expected_tmp=$(mktemp)
    local student_tmp=$(mktemp)
    
    echo "$expected_data" > "$expected_tmp"
    echo "$student_data" > "$student_tmp"
    
    diff -U 3 "$expected_tmp" "$student_tmp" | while IFS= read -r line; do
        case "$line" in           
            ---*|+++*|@@*)
                ;;
            -*)                
                echo "      👉 EXPECTED: ${line#-}"
                ;;
            +*)
                echo "      ❌ YOUR OUTPUT: ${line#+}"                
                ;;
            *)
                echo "         ${line}"                
                ;;                
        esac
    done || true
    
    rm -f "$expected_tmp" "$student_tmp"
    
    # Show statistics
    local expected_lines=$(wc -l < "$expected_file" 2>/dev/null || echo "0")
    local student_lines=$(wc -l < "$student_output" 2>/dev/null || echo "0")
    echo -e "${CYAN}   Statistics: Expected=$expected_lines lines, Yours=$student_lines lines${NC}"
    echo
}
# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================
validate_test_weights() {
    local total_weight=0
    
    # Calculate sum of all weights using bc for floating point
    for weight in "${TEST_WEIGHTS[@]}"; do
        total_weight=$(echo "$total_weight + $weight" | bc -l)
    done
    
    # Add synchronization test points
    total_weight=$(echo "$total_weight + $DEADLOCK_POINTS + $RACE_CONDITION_POINTS" | bc -l)
    
    # Use bc to compare floating point numbers
    local weights_match=$(echo "$total_weight == $TOTAL_POINTS" | bc -l)
    
    if [[ $weights_match -ne 1 ]]; then
        print_error "Test weights ($total_weight) don't sum to TOTAL_POINTS ($TOTAL_POINTS)!"
        exit 1
    fi
}

validate_test_files() {
    print_info "Validating test files..."
    
    for test_num in "${!TEST_WEIGHTS[@]}"; do
        local input_file="Testing/Testcases/input${test_num}.txt"
        local expected_file="Testing/Expected_Output/output${test_num}.txt"
        
        if [[ ! -f "$input_file" ]]; then
            print_error "Input file $input_file not found for test case $test_num"
            exit 1
        fi
        
        if [[ ! -f "$expected_file" ]]; then
            print_error "Expected output file $expected_file not found for test case $test_num"
            exit 1
        fi
    done
    
    print_success "All test files validated"
}

# =============================================================================
# MAIN GRADING FUNCTIONS
# =============================================================================

compile_code() {
    print_info "Compiling your code..."
    
    local makefile_to_use=$(find_makefile)
    
    if [[ -n "$makefile_to_use" ]]; then
        print_success "Found $makefile_to_use to compile"
    else
        print_error "No Makefile found!"
        echo "Please ensure a Makefile is present in the current directory."
        echo "Supported name: Makefile"
        echo
        echo "📊 FINAL GRADE: 0/$TOTAL_POINTS (Code must compile to earn points)"
        exit 1
    fi
    
    if make -f "$makefile_to_use" clean > /dev/null 2>&1 && make -f "$makefile_to_use" 2> Results/compile_errors.txt; then
        print_success "Code compiled successfully!"
    else
        print_error "Code failed to compile"
        echo
        echo "Compilation errors:"
        cat Results/compile_errors.txt | head -20
        echo
        echo "📊 FINAL GRADE: 0/$TOTAL_POINTS (Code must compile to earn points)"
        exit 1
    fi
    
    if [[ ! -x "$EXECUTABLE_NAME" ]]; then
        print_error "Executable $EXECUTABLE_NAME not created"
        echo
        echo "📊 FINAL GRADE: 0/$TOTAL_POINTS (Executable must be created to earn points)"
        exit 1
    fi
}

run_functionality_tests() {
    echo
    echo "🧪 TEST 1: Functionality & Correctness Tests"
    echo
    
    # Get sorted list of test numbers from weights
    local test_numbers=($(printf '%s\n' "${!TEST_WEIGHTS[@]}" | sort -n))
    TOTAL_TESTS=${#test_numbers[@]}
    
    echo "Found $TOTAL_TESTS test case(s)"
    echo
    
    # Initialize test scores array
    for ((i=0; i<TOTAL_TESTS; i++)); do
        TEST_SCORES[i]=0
    done
    
    # Run each test
    local test_index=0
    for test_num in "${test_numbers[@]}"; do
        local input_file="Testing/Testcases/input${test_num}.txt"
        local expected_file="Testing/Expected_Output/output${test_num}.txt"
        local test_weight=${TEST_WEIGHTS[$test_num]}
        
        echo "🔬 Test Case $test_num (input${test_num}.txt) - ${test_weight} points:"
        
        # Run student's program
        local student_output="Results/student_output_${test_num}.txt"
        timeout "$TIMEOUT_SECONDS" ./"$EXECUTABLE_NAME" "$input_file" > "$student_output" 2>/dev/null
        local exit_code=$?
        
        # Determine if program crashed
        local crashed=0
        if [[ $exit_code -eq 124 ]]; then
            print_error "Test Case $test_num TIMEOUT"
            crashed=1
        elif [[ $exit_code -gt 128 ]]; then
            print_error "Test Case $test_num CRASHED"
            crashed=1
        fi
        
        # Calculate proportional score for this test
        local score=$(calculate_proportional_score "$test_num" "$expected_file" "$student_output" "$crashed")
        TEST_SCORES[$test_index]=$score
        
        # Display result
        if [[ $crashed -eq 1 ]]; then
            echo "   ⚠️ Program crashed or timed out"
        elif [[ $(echo "$score == 1.0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            print_success "Test Case $test_num PASSED (100%)"
        else
            local percentage=$(echo "scale=0; ($score * 100 + 0.5) / 1" | bc -l 2>/dev/null || echo "0")
            local points_earned=$(echo "scale=1; $score * $test_weight" | bc -l 2>/dev/null || echo "0")
            print_partial "Test Case $test_num PARTIAL (${percentage}% = ${points_earned}/${test_weight} points)"
            show_section_differences "$test_num" "$expected_file" "$student_output" "$score" "$test_weight"
        fi
        
        ((test_index++))
        echo
    done
}

run_synchronization_tests() {
    echo
    echo "🧪 TEST 2: Synchronization Tests"
    echo
    
    local input_file="Testing/Testcases/input1.txt"
    
    # Test 2.1: Deadlock detection (run test case 1 multiple times)
    echo "🔬 Test 2.1: Deadlock detection (500 runs of test case 1) - ${DEADLOCK_POINTS} points:"
    echo "⚠️ Please be patient! It may take some time..."
    local DEADLOCK_DETECTED=false
    local deadlock_run=0
    
    for run in $(seq 1 500); do
        timeout 5 ./"$EXECUTABLE_NAME" "$input_file" > /dev/null 2>&1
        local exit_code=$?
        
        if [[ $exit_code -eq 124 ]]; then
            echo "   Run $run: TIMEOUT (deadlock suspected)"
            DEADLOCK_DETECTED=true
            deadlock_run=$run
            break
        fi
    done
    
    if [[ "$DEADLOCK_DETECTED" = false ]]; then
        print_success "No deadlock detected in 500 runs"
        DEADLOCK_SCORE=1.0
    else
        print_error "Deadlock detected on run $deadlock_run"
        DEADLOCK_SCORE=0
    fi
    echo
    
    # Test 2.2: Race condition detection (consistency check with multiple runs)
    echo "🔬 Test 2.2: Race condition detection (500 runs for consistency) - ${RACE_CONDITION_POINTS} points:"
    echo "⚠️ Please be patient! It may take some time..."
    local RACE_DETECTED=false
    local INCONSISTENT_RUN=0
    
    # First, get a baseline output
    timeout 5 ./"$EXECUTABLE_NAME" "$input_file" > "Results/race_baseline.txt" 2>&1
    local baseline_exit=$?
    
    if [[ $baseline_exit -ne 0 && $baseline_exit -ne 124 ]]; then
        print_error "Program crashed on baseline run"
        RACE_CONDITION_SCORE=0
    elif [[ $baseline_exit -eq 124 ]]; then
        print_error "Program timed out (deadlock)"
        RACE_CONDITION_SCORE=0
    else
        # Now run multiple times and check for consistency
        local inconsistent_count=0
        
        for run in $(seq 1 500); do
            timeout 5 ./"$EXECUTABLE_NAME" "$input_file" > "Results/race_test_${run}.txt" 2>&1
            local exit_code=$?
            
            if [[ $exit_code -eq 124 ]]; then
                echo "   Run $run: TIMEOUT"
                RACE_DETECTED=true
                INCONSISTENT_RUN=$run
                inconsistent_count=$((inconsistent_count + 1))
            elif [[ $exit_code -ne 0 ]]; then
                echo "   Run $run: CRASH"
                RACE_DETECTED=true
                INCONSISTENT_RUN=$run
                inconsistent_count=$((inconsistent_count + 1))
            elif [[ -f "Results/race_test_${run}.txt" ]]; then
                # Check if output is consistent with baseline
                if ! cmp -s "Results/race_baseline.txt" "Results/race_test_${run}.txt"; then
                    if [[ $inconsistent_count -eq 0 ]]; then
                        echo "   Run $run: INCONSISTENT OUTPUT"
                    fi
                    RACE_DETECTED=true
                    INCONSISTENT_RUN=$run
                    inconsistent_count=$((inconsistent_count + 1))
                fi
            fi
            
            # Stop early if we found enough inconsistencies
            if [[ $inconsistent_count -ge 3 ]]; then
                echo "   ... (stopping after $inconsistent_count inconsistencies detected)"
                break
            fi
        done
        
        if [[ "$RACE_DETECTED" = false ]]; then
            print_success "Consistent output across 500 runs (no race conditions)"
            RACE_CONDITION_SCORE=1.0
        else
            print_error "Detected $inconsistent_count inconsistent run(s) - race condition suspected"
            echo "   Non-deterministic behavior indicates improper synchronization..."
            if [[ "$RACE_DETECTED" = true && $INCONSISTENT_RUN -gt 0 ]]; then
                echo "   Showing difference between baseline and inconsistent run $INCONSISTENT_RUN:"
                show_section_differences "2.2" "Results/race_baseline.txt" "Results/race_test_${INCONSISTENT_RUN}.txt" "0" "$RACE_CONDITION_POINTS"
            fi
            RACE_CONDITION_SCORE=0
        fi
    fi
    echo
}

calculate_final_grade() {
    local final_score=0
    local test_numbers=($(printf '%s\n' "${!TEST_WEIGHTS[@]}" | sort -n))
    
    # Calculate weighted score from all functionality tests
    for ((i=0; i<${#test_numbers[@]}; i++)); do
        local test_num="${test_numbers[i]}"
        local test_weight=${TEST_WEIGHTS[$test_num]}
        local test_score=${TEST_SCORES[i]}
        
        if [[ -n "$test_score" && "$test_score" != "0" ]]; then
            local points=$(echo "scale=2; $test_score * $test_weight" | bc -l 2>/dev/null || echo "0")
            final_score=$(echo "scale=2; $final_score + $points" | bc -l 2>/dev/null || echo "$final_score")
        fi
    done
    
    # Add synchronization test scores
    local deadlock_points=$(echo "scale=2; $DEADLOCK_SCORE * $DEADLOCK_POINTS" | bc -l 2>/dev/null || echo "0")
    local race_points=$(echo "scale=2; $RACE_CONDITION_SCORE * $RACE_CONDITION_POINTS" | bc -l 2>/dev/null || echo "0")
    
    final_score=$(echo "scale=2; $final_score + $deadlock_points + $race_points" | bc -l 2>/dev/null || echo "$final_score")
    
    # Round to nearest integer
    FINAL_SCORE=$(echo "scale=0; ($final_score + 0.5) / 1" | bc -l 2>/dev/null || echo "0")
}

generate_results() {
    calculate_final_grade
    
    local percentage=$((FINAL_SCORE * 100 / TOTAL_POINTS))
    
    echo "📊 GRADE SUMMARY"
    echo "=========================="
    echo "TEST 1: Functionality & Correctness Tests"
    
    local test_numbers=($(printf '%s\n' "${!TEST_WEIGHTS[@]}" | sort -n))
    for ((i=0; i<${#test_numbers[@]}; i++)); do
        local test_num="${test_numbers[i]}"
        local test_weight=${TEST_WEIGHTS[$test_num]}
        local test_score=${TEST_SCORES[i]}
        local points=$(echo "scale=1; $test_score * $test_weight" | bc -l 2>/dev/null || echo "0")
        local percentage=$(echo "scale=1; $test_score * 100" | bc -l 2>/dev/null || echo "0")
        printf "  Test Case %s (input%s.txt): %.1f/%.0f points\n" "$test_num" "$test_num" "$points" "$test_weight"
    done
    
    echo
    echo "TEST 2: Synchronization Tests"
    local deadlock_points=$(echo "scale=1; $DEADLOCK_SCORE * $DEADLOCK_POINTS" | bc -l 2>/dev/null || echo "0")
    local deadlock_percentage=$(echo "scale=1; $DEADLOCK_SCORE * 100" | bc -l 2>/dev/null || echo "0")
    printf "  Test 2.1 (Deadlock detection): %.1f/%.0f points\n" "$deadlock_points" "$DEADLOCK_POINTS" 
    
    local race_points=$(echo "scale=1; $RACE_CONDITION_SCORE * $RACE_CONDITION_POINTS" | bc -l 2>/dev/null || echo "0")
    local race_percentage=$(echo "scale=1; $RACE_CONDITION_SCORE * 100" | bc -l 2>/dev/null || echo "0")
    printf "  Test 2.2 (Race condition detection): %.1f/%.0f points\n" "$race_points" "$RACE_CONDITION_POINTS"
    
    echo "=========================="
    echo "FINAL GRADE: $FINAL_SCORE/$TOTAL_POINTS"
    
    # Motivational messages
    local percentage_int=$(echo "scale=0; ($percentage + 0.5) / 1" | bc -l 2>/dev/null || echo "0")

    if [[ $percentage_int -ge 90 ]]; then
        echo -e "\n🎉 Excellent work!"
    elif [[ $percentage_int -ge 80 ]]; then
        echo -e "\n👍 Great job!"
    elif [[ $percentage_int -ge 70 ]]; then
        echo -e "\n✅ Good work!"
    elif [[ $percentage_int -ge 60 ]]; then
        echo -e "\n📚 Getting there - keep practicing!"
    else
        echo -e "\n💪 Don't give up - review the feedback and try again!"
    fi
}

export_csv() {
    local csv_file="Results/grade.csv"
    local zip_name="${STUDENT_ZIP_NAME:-Unknown}"
    
    # Create CSV file
    {
        echo "zip_filename,assignment_name,final_score"
        echo "${zip_name},${ASSIGNMENT_NAME},${FINAL_SCORE}"
    } > "$csv_file"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "🎯 Assignment: $ASSIGNMENT_NAME"
    #echo "📅 Student: ${STUDENT_ZIP_NAME:-Unknown}"
    echo "⏰ Submission: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    # Create Results directory
    mkdir -p Results
    
    # Validate configuration
    validate_test_weights
    validate_test_files
    
    # Grade the submission
    compile_code
    run_functionality_tests
    run_synchronization_tests
    generate_results
    export_csv
    
    echo
    
    exit 0
}

# Check if bc is available for calculations
if ! command -v bc &> /dev/null; then
    print_error "bc (calculator) not found - please install bc package"
    exit 1
fi

# Execute main function
main "$@"