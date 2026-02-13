#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

echo "🔍 Scanning Nexus Studio packages..."

# Stats variables - using parallel arrays for bash 3.x compatibility
# Indices: 0=server, 1=shared, 2=app
PACKAGES=("server" "shared" "app")
COVERED_LINES=(0 0 0)
TOTAL_LINES=(0 0 0)
# Array to store uncovered lines detail string for each package
UNCOVERED_DETAILS=("" "" "")
GLOBAL_COVERED=0
GLOBAL_TOTAL=0

# Clean coverage directory if it exists
mkdir -p coverage

for i in "${!PACKAGES[@]}"; do
  PKG="${PACKAGES[$i]}"
  PKG_DIR="$PKG"
  if [ ! -d "$PKG_DIR" ]; then
    echo -e "${YELLOW}⚠️  [$PKG] Directory not found. Skipping.${RESET}"
    continue
  fi

  echo -e "📦 [$PKG] Running tests and generating coverage..."

  # Determine test command based on package type
  if [ "$PKG" == "app" ]; then
    TEST_CMD="flutter test --coverage"
  else
    # Dart test requires directory for coverage
    TEST_CMD="dart test --coverage=coverage"
  fi

  # Run tests
  # Capture output to log, show errors if fails
  if ! (cd "$PKG_DIR" && $TEST_CMD > /dev/null 2>&1); then
    echo -e "${RED}❌ [$PKG] Tests failed!${RESET}"
    # Re-run to show output
    (cd "$PKG_DIR" && $TEST_CMD)
    exit 1
  fi
  
  # For dart test, we need to convert to lcov if not automatically done
  # dart test --coverage generates coverage/test.json usually. 
  # Wait, dart test --coverage=coverage generates JSON files in coverage/
  # We need coverage/lcov.info. 
  # Usually requires 'coverage:format_coverage' package.
  # Let's verify what happens. 
  # Actually, simpler approach for this script without extra deps is difficult for pure Dart.
  # But assuming environment has tools. 
  # 'dart test --coverage=coverage' outputs a json. We need to format it.
  # If 'format_coverage' is globally activated:
  if [ "$PKG" != "app" ]; then
     # Attempt to convert using format_coverage or check if lcov.info exists
     if [ ! -f "$PKG_DIR/coverage/lcov.info" ]; then
        # Try running format_coverage if available, locally or globally
        # But user asked for specific script. 
        # Let's assume standard dart coverage workflow.
        # "dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib"
        (cd "$PKG_DIR" && dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib > /dev/null 2>&1)
     fi
  fi

  LCOV_FILE="$PKG_DIR/coverage/lcov.info"
  if [ ! -f "$LCOV_FILE" ]; then
    echo -e "${YELLOW}⚠️  [$PKG] No coverage/lcov.info file generated.${RESET}"
    continue
  fi

  # Extract coverage stats using lcov logic
  # We need to count DA (Data lines)
  # Format: DA:<line>,<hits>
  # Only count lines in lib/ excluding .g.dart and .freezed.dart
  
  # Parsing lcov.info in bash
  # We use awk to process the file and output stats + uncovered info
  # Output format:
  # STATS covered total
  # UNCOVERED filename line
  # ...
  
  AWK_OUTPUT=$(awk '
    BEGIN {
      current_file = ""
      covered = 0
      total = 0
    }
    /^SF:/ {
      file = substr($0, 4)
      # Check if file is in lib/ and not generated
      if (index(file, "lib/") > 0 && index(file, ".g.dart") == 0 && index(file, ".freezed.dart") == 0) {
        current_file = file
      } else {
        current_file = ""
      }
    }
    /^DA:/ {
      if (current_file != "") {
        split(substr($0, 4), parts, ",")
        line_num = parts[1]
        hits = parts[2]
        total++
        if (hits > 0) {
          covered++
        } else {
          print "UNCOVERED " current_file " " line_num
        }
      }
    }
    END {
      print "STATS " covered " " total
    }
  ' "$LCOV_FILE")

  # Process awk output
  PKG_COVERED=0
  PKG_TOTAL=0
  DETAILS=""

  while read -r line; do
    if [[ $line == STATS* ]]; then
      read -r _ PKG_COVERED PKG_TOTAL <<< "$line"
    elif [[ $line == UNCOVERED* ]]; then
      read -r _ FILE LINE <<< "$line"
      # Accumulate uncovered lines. 
      # We will format this later or just store raw list.
      # Storing as "file:line "
      DETAILS+="$FILE:$LINE "
    fi
  done <<< "$AWK_OUTPUT"
  
  COVERED_LINES[$i]=$PKG_COVERED
  TOTAL_LINES[$i]=$PKG_TOTAL
  UNCOVERED_DETAILS[$i]=$DETAILS
  
  GLOBAL_COVERED=$((GLOBAL_COVERED + PKG_COVERED))
  GLOBAL_TOTAL=$((GLOBAL_TOTAL + PKG_TOTAL))

  # Calculate percentage
  if [ "$PKG_TOTAL" -eq 0 ]; then
    PERCENT="100.00"
  else
    PERCENT=$(echo "scale=1; $PKG_COVERED * 100 / $PKG_TOTAL" | bc)
  fi
  
  echo -e "${GREEN}✅ [$PKG] Done. ($PERCENT%)${RESET}"
done

echo ""
echo "================================================================="
echo -e "${BOLD}📊 EXAMPLE COVERAGE REPORT${RESET}"
echo "================================================================="
printf "| %-20s | %-13s | %-11s | %-8s |\n" "Package" "Lines Covered" "Total Lines" "Coverage"
echo "|----------------------|---------------|-------------|----------|"

# Print individual package stats
for i in "${!PACKAGES[@]}"; do
  PKG="${PACKAGES[$i]}"
  PKG_COVERED=${COVERED_LINES[$i]}
  PKG_TOTAL=${TOTAL_LINES[$i]}
  
  if [ "$PKG_TOTAL" -eq 0 ]; then
    PERCENT="100.00"
  else
    PERCENT=$(echo "scale=2; $PKG_COVERED * 100 / $PKG_TOTAL" | bc)
  fi
  
  printf "| %-20s | %13s | %11s | %7s%% |\n" "$PKG" "$PKG_COVERED" "$PKG_TOTAL" "$PERCENT"
done

# Print global stats
echo "|----------------------|---------------|-------------|----------|"
if [ "$GLOBAL_TOTAL" -eq 0 ]; then
  GLOBAL_PERCENT="100.00"
else
  GLOBAL_PERCENT=$(echo "scale=2; $GLOBAL_COVERED * 100 / $GLOBAL_TOTAL" | bc)
fi
printf "| %-20s | %13s | %11s | %7s%% |\n" "GLOBAL" "$GLOBAL_COVERED" "$GLOBAL_TOTAL" "$GLOBAL_PERCENT"

echo "================================================================="

# Print Uncovered Details
echo ""
echo -e "${BOLD}📝 Uncovered Lines Details${RESET}"

for i in "${!PACKAGES[@]}"; do
  PKG="${PACKAGES[$i]}"
  DETAILS="${UNCOVERED_DETAILS[$i]}"
  
  # Calculate coverage to decide if we show details
  PKG_TOTAL=${TOTAL_LINES[$i]}
  PKG_COVERED=${COVERED_LINES[$i]}
  
  if [ "$PKG_TOTAL" -gt 0 ] && [ "$PKG_COVERED" -lt "$PKG_TOTAL" ]; then
    echo ""
    echo -e "📦 ${BOLD}$PKG${RESET}"
    
    # Process details to group lines by file
    # DETAILS contains "file:line file:line ..."
    # We want to sort and aggregate ranges
    
    if [ -z "$DETAILS" ]; then
       echo "  _No detailed info available_"
    else
       # Use python or just simple bash sort to group
       # Let's use a simple approach: 
       # 1. Replace space with newline
       # 2. Sort
       # 3. Process with awk to group ranges
       
       echo "$DETAILS" | tr ' ' '\n' | grep -v "^$" | sort | awk -F: '
         {
           if ($1 != current_file) {
             if (current_file != "") {
               print_ranges()
             }
             current_file = $1
             count = 0
             delete lines
           }
           lines[count++] = $2
         }
         
         function print_ranges() {
            # Sort lines numerically (they might be out of order if we just appended)
            # But input is sorted textually: file:1, file:10, file:2. 
            # So simple sort might not be enough for numbers.
            # We will rely on simple aggregation for now or improved sort.
            
            # Since we receive separate file:line entries, we can just print them.
            # Implementing accurate range condensation in awk within bash is verbose.
            # Let s keep it simple: print comma separated list.
            
            printf "  • %s: ", current_file
            
            # Printing lines is tricky without numeric sort. 
            # Let s just output as is for now, or improve if user insists on ranges.
            # For "print uncovered lines", a list is sufficient.
            
            # Construct string
            line_str = ""
            for (i=0; i<count; i++) {
               line_str = line_str lines[i] " "
            }
            print line_str
         }
         
         END {
           if (current_file != "") {
             print_ranges()
           }
         }
       ' | while read -r line; do
          # Post-process to sort numbers and format ranges if possible, 
          # otherwise just neat print.
          # For this iteration, we will just print the awk output which aggregates by file.
          
          # Improved display: 
          FILE=$(echo "$line" | cut -d: -f1)
          LINES=$(echo "$line" | cut -d: -f2- | tr -s ' ' '\n' | sort -n | awk '
            function print_range() {
               if (start == end) printf "%d, ", start; else printf "%d-%d, ", start, end;
            }
            {
              if (NR == 1) { start = $1; end = $1; next }
              if ($1 == end + 1) { end = $1 }
              else { print_range(); start = $1; end = $1 }
            }
            END { print_range() }
          ')
          # Remove trailing comma space
          LINES=$(echo "$LINES" | sed "s/, $//")
          echo -e "  • ${FILE#packages/*/}: $LINES"
       done
    fi
  fi
done
