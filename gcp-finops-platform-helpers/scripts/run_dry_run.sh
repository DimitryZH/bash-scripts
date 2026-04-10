#!/usr/bin/env bash
set -euo pipefail

# Unified dry-run execution entrypoint.
# This wrapper is intentionally minimal and transparent.
#
# Required:
# - PROJECT_SCOPE: comma-separated project IDs in scope
# - DRY_RUN_CMD: exact command used to execute the assessment
#
# Optional:
# - CONFIG_PATH: path to config file if your runtime uses one
# - OUTPUT_HINT: where report/log output is expected

PROJECT_SCOPE="${PROJECT_SCOPE:-REPLACE_WITH_PROJECT_ID_1,REPLACE_WITH_PROJECT_ID_2}"
DRY_RUN_CMD="${DRY_RUN_CMD:-REPLACE_WITH_ASSESSMENT_COMMAND}"
CONFIG_PATH="${CONFIG_PATH:-}"
OUTPUT_HINT="${OUTPUT_HINT:-./artifacts/}"

if [[ "$PROJECT_SCOPE" == "REPLACE_WITH_PROJECT_ID_1,REPLACE_WITH_PROJECT_ID_2" ]]; then
  echo "ERROR: Set PROJECT_SCOPE before running."
  echo "Example: PROJECT_SCOPE=\"proj-a,proj-b\" ./scripts/run_dry_run.sh"
  exit 1
fi

if [[ "$DRY_RUN_CMD" == "REPLACE_WITH_ASSESSMENT_COMMAND" ]]; then
  echo "ERROR: Set DRY_RUN_CMD to the exact assessment command before running."
  echo "Example: DRY_RUN_CMD=\"python -m app.main\" PROJECT_SCOPE=\"proj-a,proj-b\" ./scripts/run_dry_run.sh"
  exit 1
fi

# Runtime compatibility:
# If the command references `uvicorn` directly but it's not on PATH,
# transparently switch to `python -m uvicorn` when available.
if [[ "$DRY_RUN_CMD" == *"uvicorn "* ]] && ! command -v uvicorn >/dev/null 2>&1; then
  if python -m uvicorn --version >/dev/null 2>&1; then
    echo "INFO: 'uvicorn' not found on PATH; using 'python -m uvicorn' fallback."
    DRY_RUN_CMD="${DRY_RUN_CMD//uvicorn /python -m uvicorn }"
  else
    echo "ERROR: uvicorn is not available in this environment."
    echo "Install uvicorn in the active Python environment or adjust DRY_RUN_CMD."
    exit 1
  fi
fi

echo "=== Dry Run: Starting assessment ==="
echo "Scope: ${PROJECT_SCOPE}"
if [[ -n "$CONFIG_PATH" ]]; then
  echo "Config path: ${CONFIG_PATH}"
else
  echo "Config path: (not provided)"
fi
echo "Expected output location: ${OUTPUT_HINT}"
echo "Command to execute: ${DRY_RUN_CMD}"
echo

# Export scope/config for runtime resolution.
export PROJECT_SCOPE
export TARGET_PROJECTS="${TARGET_PROJECTS:-$PROJECT_SCOPE}"
export CONFIG_PATH

eval "${DRY_RUN_CMD}"

echo
echo "=== Dry Run: Execution finished ==="
echo "Capture report artifact and log paths under: ${OUTPUT_HINT}"
