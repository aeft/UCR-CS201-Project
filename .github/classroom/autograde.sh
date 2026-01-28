#!/usr/bin/env bash
set -euo pipefail

# Require explicit project argument (no default)
if [ "$#" -ne 1 ]; then
  echo "Usage: autograde.sh <project>"
  echo "Example: autograde.sh project2"
  exit 1
fi

PROJ="$1"
IMAGE="ghcr.io/ucr-cs201/grader:llvm21"

# Pull prebuilt grader image (fast & stable)
docker pull "$IMAGE"

# Per-project configuration
# Extend by adding new cases (e.g., project3)
case "$PROJ" in
  project2)
    # Path to the ONLY file students are allowed to modify (in submission repo)
    STUDENT_CPP_SRC="/submission/project2/LocalValueNumbering.cpp"

    # Destination path in the baseline (main branch) workspace
    BASE_CPP_DST="/work/project2/LocalValueNumbering.cpp"

    # Canonical test entry (must print Results: X passed, Y failed)
    TEST_CMD='cd project2 && ./test.sh'
    ;;
  *)
    echo "Unknown project: $PROJ"
    exit 1
    ;;
esac

# Run grading inside container
docker run --rm \
  -v "$PWD:/submission:ro" \
  "$IMAGE" \
  bash -lc "
    set -euo pipefail

    # Clone a clean baseline
	git clone --depth 1 --branch main https://github.com/aeft/UCR-CS201-Project.git /work
    cd /work

    # Ensure the allowed student file exists
    test -f '$STUDENT_CPP_SRC'

    # Copy ONLY the allowed file into the baseline
    cp '$STUDENT_CPP_SRC' '$BASE_CPP_DST'

    # Run canonical tests with line-buffered output
    stdbuf -oL -eL bash -lc \"$TEST_CMD\"
  "

