#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

PROGRAM_NAME="$(basename "$0")"
VERSION="1.0.0"

PROJECT_ID="${PROJECT_ID:-REPLACE_WITH_GCP_PROJECT_ID}"
CONFIG_FILE=""

REQUIRED_APIS=(
  "compute.googleapis.com"
  "iap.googleapis.com"
  "serviceusage.googleapis.com"
  "cloudresourcemanager.googleapis.com"
)

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<EOF
${PROGRAM_NAME} ${VERSION}

Read-only Google Cloud readiness check for a GCE DevBox.

Usage:
  ${PROGRAM_NAME} [options]

Options:
  --config PATH       Load settings from a safe key/value config file.
  --project-id ID     Target Google Cloud project ID.
  -h, --help          Show this help.
  --version           Show the version.
EOF
}


trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_matching_quotes() {
  local value="$1"
  if [[ ${#value} -ge 2 ]]; then
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  printf '%s' "$value"
}

normalize_bool() {
  case "${1,,}" in
    true|1|yes|on) printf 'true' ;;
    false|0|no|off) printf 'false' ;;
    *)
      printf 'ERROR: invalid boolean value: %s\n' "$1" >&2
      return 1
      ;;
  esac
}


load_config() {
  local file="$1"
  local raw line key value line_number=0

  if [[ ! -r "$file" ]]; then
    printf 'ERROR: config file is not readable: %s\n' "$file" >&2
    exit 2
  fi

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line_number=$((line_number + 1))
    line="$(trim "$raw")"
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" != *=* ]]; then
      printf 'ERROR: invalid config entry at %s:%d\n' "$file" "$line_number" >&2
      exit 2
    fi

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    value="$(strip_matching_quotes "$value")"

    case "$key" in
      PROJECT_ID) PROJECT_ID="$value" ;;
      REGION) : ;;
      ZONE) : ;;
      VM_NAME) : ;;
      MACHINE_TYPE) : ;;
      BOOT_DISK_SIZE_GB) : ;;
      BOOT_DISK_TYPE) : ;;
      IMAGE_FAMILY) : ;;
      IMAGE_PROJECT) : ;;
      NETWORK) : ;;
      SUBNET) : ;;
      NETWORK_TAGS) : ;;
      CREATE_EXTERNAL_IP) : ;;
      IAP_ALLOW_FIREWALL_RULE) : ;;
      PUBLIC_SSH_DENY_FIREWALL_RULE) : ;;
      REQUIRE_IAP_FIREWALL_RULE) : ;;
      REQUIRE_PUBLIC_SSH_DENY_RULE) : ;;
      ENABLE_OS_LOGIN) : ;;
      NO_SERVICE_ACCOUNT) : ;;
      LABELS) : ;;
      TUNNEL_THROUGH_IAP) : ;;
      MIN_CPU_COUNT) : ;;
      MIN_MEMORY_GB) : ;;
      MIN_FREE_DISK_GB) : ;;
      REQUIRED_TOOLS) : ;;
      OPTIONAL_BROWSER_CHECK) : ;;
      EVIDENCE_OUTPUT_DIR) : ;;
      VALIDATION_LOG_DIR) : ;;
      MAX_LOG_LINES) : ;;
      INCLUDE_DOCKER_DETAILS) : ;;
      INCLUDE_GIT_STATUS) : ;;
      *)
        printf 'ERROR: unsupported config key at %s:%d: %s\n' \
          "$file" "$line_number" "$key" >&2
        exit 2
        ;;
    esac
  done < "$file"
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$1"
}

print_summary() {
  printf '\n=== Summary ===\n'
  printf 'pass=%s\nwarn=%s\nfail=%s\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
}

args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    --config)
      if ((i + 1 >= ${#args[@]})); then
        printf 'ERROR: --config requires a path.\n' >&2
        exit 2
      fi
      CONFIG_FILE="${args[$((i + 1))]}"
      ;;
    --config=*) CONFIG_FILE="${args[$i]#*=}" ;;
  esac
done

if [[ -n "$CONFIG_FILE" ]]; then
  load_config "$CONFIG_FILE"
fi

while (($# > 0)); do
  case "$1" in
    --config) shift 2 ;;
    --config=*) shift ;;
    --project-id) PROJECT_ID="${2:?ERROR: --project-id requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --version) printf '%s %s\n' "$PROGRAM_NAME" "$VERSION"; exit 0 ;;
    *)
      printf 'ERROR: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "REPLACE_WITH_GCP_PROJECT_ID" ]]; then
  printf 'ERROR: set PROJECT_ID in config, environment, or --project-id.\n' >&2
  exit 2
fi

printf 'Checking local Google Cloud readiness for project: %s\n\n' "$PROJECT_ID"

if ! command -v gcloud >/dev/null 2>&1; then
  fail "gcloud is not installed or is not on PATH."
  print_summary
  exit 1
fi

GCLOUD_VERSION="$(gcloud version --format='value(Google Cloud SDK)' 2>/dev/null || true)"
if [[ -n "$GCLOUD_VERSION" ]]; then
  pass "gcloud is installed: $GCLOUD_VERSION"
else
  pass "gcloud is installed."
fi

ACTIVE_ACCOUNT="$(gcloud auth list --filter='status:ACTIVE' --format='value(account)' 2>/dev/null | head -n 1 || true)"
if [[ -n "$ACTIVE_ACCOUNT" ]]; then
  pass "Active authenticated account detected: $ACTIVE_ACCOUNT"
else
  fail "No active authenticated account. Run: gcloud auth login"
fi

ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -n "$ACTIVE_PROJECT" && "$ACTIVE_PROJECT" != "(unset)" ]]; then
  pass "Active gcloud project is visible: $ACTIVE_PROJECT"
else
  warn "No active project is configured."
fi

if gcloud projects describe "$PROJECT_ID" --format='value(projectId)' >/dev/null 2>&1; then
  pass "Project is accessible: $PROJECT_ID"
else
  fail "Project is not accessible. Confirm permissions and project ID: $PROJECT_ID"
fi

if [[ "$ACTIVE_PROJECT" == "$PROJECT_ID" ]]; then
  pass "Active project matches the target project."
else
  warn "Active project does not match the target project. Commands still use explicit --project."
fi

ENABLED_APIS="$(gcloud services list --enabled --project "$PROJECT_ID" --format='value(config.name)' 2>/dev/null || true)"
if [[ -z "$ENABLED_APIS" ]]; then
  warn "Could not list enabled APIs. Confirm Service Usage permissions."
else
  for api in "${REQUIRED_APIS[@]}"; do
    if printf '%s\n' "$ENABLED_APIS" | grep -Fxq "$api"; then
      pass "Required API is enabled: $api"
    else
      warn "Required API may be missing: $api"
    fi
  done
fi

printf '\nThis script does not enable APIs or create resources.\n'
print_summary

if ((FAIL_COUNT > 0)); then
  exit 1
fi
