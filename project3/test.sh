#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#===============================================================================
# LLVM AUTO-DETECTION
#===============================================================================
detect_llvm() {
  # If user has set LLVM_DIR, use it
  if [ -n "$LLVM_DIR" ]; then
    echo "Using user-specified LLVM_DIR: $LLVM_DIR"
    return
  fi

  echo "Auto-detecting LLVM installation..."

  # Try common installation locations (newest versions first)
  LOCATIONS=(
    "/opt/homebrew/opt/llvm"       # Homebrew macOS (latest)
    "/opt/homebrew/opt/llvm@21"    # Homebrew macOS (LLVM 21)
    "/usr/lib/llvm-21"             # Ubuntu/Debian
    "/lib/llvm-21"                 # Ubuntu/Debian (alternative)
  )

  for loc in "${LOCATIONS[@]}"; do
    if [ -f "$loc/bin/llvm-config" ]; then
      LLVM_DIR="$loc"
      echo -e "${GREEN}Auto-detected LLVM at: $LLVM_DIR${NC}"
      return
    fi
  done

  # Try using llvm-config in PATH
  if command -v llvm-config >/dev/null 2>&1; then
    LLVM_DIR="$(llvm-config --prefix)"
    echo -e "${GREEN}Found LLVM via llvm-config: $LLVM_DIR${NC}"
    return
  fi

  # LLVM not found
  echo -e "${RED}Error: LLVM installation not found.${NC}" >&2
  echo "" >&2
  echo "Please install LLVM 21+ or set LLVM_DIR environment variable:" >&2
  echo "  - macOS:  brew install llvm" >&2
  echo "  - Ubuntu: sudo apt-get install llvm-21-dev clang-21" >&2
  echo "  - Manual: export LLVM_DIR=/path/to/llvm" >&2
  exit 1
}

#===============================================================================
# PLATFORM DETECTION
#===============================================================================
detect_platform() {
  case "$(uname -s)" in
    Darwin*)
      LIB_EXT="dylib"
      echo "Detected platform: macOS"
      ;;
    Linux*)
      LIB_EXT="so"
      echo "Detected platform: Linux"
      ;;
    *)
      echo -e "${RED}Error: Unsupported platform $(uname -s)${NC}" >&2
      exit 1
      ;;
  esac

  # Detect sed syntax (GNU vs BSD)
  if sed --version 2>&1 | grep -q GNU; then
    SED_INPLACE="sed -i"
  else
    SED_INPLACE="sed -i ''"
  fi
}

#===============================================================================
# BUILD LLVM PASS PLUGIN
#===============================================================================
build_plugin() {
  echo ""
  echo "Building LLVM pass plugin..."

  # Create and enter build directory
  mkdir -p build
  cd build

  # Run CMake
  echo "Running CMake configuration..."
  if ! cmake -DLT_LLVM_INSTALL_DIR="$LLVM_DIR" ..; then
    echo -e "${RED}Error: CMake configuration failed.${NC}" >&2
    echo "Please check that LLVM is properly installed." >&2
    exit 1
  fi

  # Build with parallel jobs
  echo "Compiling plugin..."
  NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
  if ! make -j"$NPROC"; then
    echo -e "${RED}Error: Compilation failed.${NC}" >&2
    exit 1
  fi

  cd ..

  # Verify the plugin was created
  if [ ! -f "build/libLivenessAnalysis.$LIB_EXT" ]; then
    echo -e "${RED}Error: Plugin library not found at build/libLivenessAnalysis.$LIB_EXT${NC}" >&2
    exit 1
  fi

  echo -e "${GREEN}Build successful: build/libLivenessAnalysis.$LIB_EXT${NC}"

  # Set up LLVM tools in PATH
  export PATH="$LLVM_DIR/bin:$PATH"
}

#===============================================================================
# RUN TESTS
#===============================================================================
run_tests() {
  echo ""
  echo "Running tests..."
  cd test

  BASE_TESTS=(basic1 basic2 basic3 basic4)

  # Create test output directory if it doesn't exist
  mkdir -p output

  # Compile and run each test
  for t in "${BASE_TESTS[@]}"; do
    echo ""
    echo "========================================="
    echo "Processing $t..."
    echo "========================================="

    # Compile test to LLVM IR
    if ! clang -c -fno-discard-value-names -emit-llvm $t.c -o output/$t.bc; then
      echo -e "${RED}Error: Failed to compile $t.c${NC}" >&2
      continue
    fi

    # Run the LLVM pass
    if ! opt -load-pass-plugin ../build/libLivenessAnalysis.$LIB_EXT \
             -passes=liveness-analysis \
             -disable-output \
             output/$t.bc 2>&1 | tee output/$t.txt; then
      echo -e "${YELLOW}Warning: opt command failed for $t${NC}" >&2
    fi
  done

  echo ""
  echo "========================================="
  echo "TEST SUMMARY"
  echo "========================================="

  passed=0
  failed=0

  for t in "${BASE_TESTS[@]}"; do
    if [ ! -f "expected/$t.txt" ] || [ ! -f "output/$t.txt" ]; then
      echo -e "${RED}$t: FAILED - Missing files${NC}"
      failed=$((failed + 1))
    else
      # Strip Dead Code section (if present) before comparing base tests
      sed '/----- Dead Code -----/,$d' output/$t.txt > output/${t}_base.txt
      if diff -b expected/$t.txt output/${t}_base.txt > /dev/null 2>&1; then
        echo -e "${GREEN}$t: PASSED${NC}"
        passed=$((passed + 1))
      else
        echo -e "${RED}$t: FAILED${NC}"
        failed=$((failed + 1))
      fi
    fi
  done

  echo ""
  echo "========================================="
  echo -e "Results: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}"
  echo "========================================="

  cd ..

  # Exit with error if any tests failed
  if [ $failed -gt 0 ]; then
    exit 1
  fi
}

#===============================================================================
# RUN BONUS TESTS (non-failing)
#===============================================================================
run_bonus_tests() {
  echo ""
  echo "========================================="
  echo "Running bonus tests..."
  echo "========================================="

  cd test
  mkdir -p output

  bonus_passed=0
  bonus_total=0

  for bonus_file in bonus*.c; do
    # Skip if no bonus files exist
    [ -e "$bonus_file" ] || continue

    bonus_name="${bonus_file%.c}"
    bonus_total=$((bonus_total + 1))

    echo ""
    echo "Processing $bonus_name..."

    # Compile test to LLVM IR
    if ! clang -c -fno-discard-value-names -emit-llvm "$bonus_file" -o "output/${bonus_name}.bc" 2>/dev/null; then
      echo -e "${YELLOW}$bonus_name: SKIPPED (compile error)${NC}"
      continue
    fi

    # Run the LLVM pass
    opt -load-pass-plugin ../build/libLivenessAnalysis.$LIB_EXT \
        -passes=liveness-analysis \
        -disable-output \
        "output/${bonus_name}.bc" 2> "output/${bonus_name}.txt" || true

    # Compare with expected output (full output including Dead Code section)
    if [ ! -f "expected/${bonus_name}.txt" ]; then
      echo -e "${YELLOW}$bonus_name: SKIPPED (no expected output)${NC}"
      continue
    fi

    if diff -b "expected/${bonus_name}.txt" "output/${bonus_name}.txt" > /dev/null 2>&1; then
      echo -e "${GREEN}$bonus_name: PASSED${NC}"
      bonus_passed=$((bonus_passed + 1))
    else
      echo -e "${YELLOW}$bonus_name: FAILED${NC}"
    fi
  done

  echo ""
  echo "========================================="
  if [ $bonus_total -gt 0 ]; then
    echo -e "${YELLOW}Bonus: $bonus_passed/$bonus_total passed${NC}"
  else
    echo -e "${YELLOW}No bonus tests found${NC}"
  fi
  echo "========================================="

  cd ..
}

#===============================================================================
# RUN SINGLE TEST (NO VALIDATION)
#===============================================================================
run_single_test() {
  local test_file=$1
  local test_name=${test_file%.c}

  echo ""
  echo "Running single test: $test_file"
  echo ""

  cd test
  mkdir -p output

  # Compile and run
  if ! clang -c -fno-discard-value-names -emit-llvm "$test_file" -o "output/${test_name}.bc"; then
    echo -e "${RED}Error: Failed to compile $test_file${NC}" >&2
    cd ..
    exit 1
  fi

  # Run the pass and save output
  opt -load-pass-plugin ../build/libLivenessAnalysis.$LIB_EXT \
      -passes=liveness-analysis \
      -disable-output \
      "output/${test_name}.bc" 2>&1 | tee "output/${test_name}.txt"

  echo ""
  echo -e "${GREEN}Output saved to: test/output/${test_name}.txt${NC}"

  cd ..
}

#===============================================================================
# MAIN
#===============================================================================
main() {
  # Parse arguments
  SINGLE_TEST=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f)
        SINGLE_TEST="$2"
        shift 2
        ;;
      *)
        echo "Usage: $0 [-f test_file.c]"
        echo "  -f test_file.c    Run single test without validation"
        exit 1
        ;;
    esac
  done

  echo "========================================"
  echo "CS201 Project 3: Liveness Analysis"
  echo "========================================"

  detect_platform
  detect_llvm
  build_plugin

  if [ -n "$SINGLE_TEST" ]; then
    run_single_test "$SINGLE_TEST"
  else
    run_tests
    run_bonus_tests
    echo ""
    echo -e "${GREEN}All done!${NC}"
  fi
}

main "$@"
