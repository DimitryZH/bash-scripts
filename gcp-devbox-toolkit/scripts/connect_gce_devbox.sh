#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PROGRAM_NAME="$(basename "$0")"
VERSION="1.0.0"

PROJECT_ID="${PROJECT_ID:-REPLACE_WITH_GCP_PROJECT_ID}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-ai-devbox-01}"
TUNNEL_THROUGH_IAP="${TUNNEL_THROUGH_IAP:-true}"
CONFIG_FILE=""

usage() {
  cat <<EOF
${PROGRAM_NAME} ${VERSION}

Connect to a Google Compute Engine DevBox.

Usage:
  ${PROGRAM_NAME} [options] [-- SSH_ARGS...]

Options:
  --config PATH       Load settings from a safe key/value config file.
  --project-id ID     Google Cloud project ID.
  --zone ZONE         Compute Engine zone.
  --vm-name NAME      VM instance name.
  --iap               Use IAP tunneling (default).
  --no-iap            Connect without IAP tunneling.
  -h, --help          Show this help.
  --version           Show the version.

Arguments after -- are forwarded to gcloud compute ssh after its separator.
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
      ZONE) ZONE="$value" ;;
      VM_NAME) VM_NAME="$value" ;;
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
      TUNNEL_THROUGH_IAP) TUNNEL_THROUGH_IAP="$value" ;;
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

PASSTHROUGH=()
while (($# > 0)); do
  case "$1" in
    --config) shift 2 ;;
    --config=*) shift ;;
    --project-id) PROJECT_ID="${2:?ERROR: --project-id requires a value}"; shift 2 ;;
    --zone) ZONE="${2:?ERROR: --zone requires a value}"; shift 2 ;;
    --vm-name) VM_NAME="${2:?ERROR: --vm-name requires a value}"; shift 2 ;;
    --iap) TUNNEL_THROUGH_IAP="true"; shift ;;
    --no-iap) TUNNEL_THROUGH_IAP="false"; shift ;;
    --)
      shift
      PASSTHROUGH=("$@")
      break
      ;;
    -h|--help) usage; exit 0 ;;
    --version) printf '%s %s\n' "$PROGRAM_NAME" "$VERSION"; exit 0 ;;
    *)
      printf 'ERROR: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

TUNNEL_THROUGH_IAP="$(normalize_bool "$TUNNEL_THROUGH_IAP")"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "REPLACE_WITH_GCP_PROJECT_ID" ]]; then
  printf 'ERROR: set PROJECT_ID before connecting.\n' >&2
  exit 2
fi

if ! command -v gcloud >/dev/null 2>&1; then
  printf 'ERROR: gcloud is not installed or is not on PATH.\n' >&2
  exit 2
fi

SSH_ARGS=(
  compute ssh "$VM_NAME"
  "--project=$PROJECT_ID"
  "--zone=$ZONE"
)

if [[ "$TUNNEL_THROUGH_IAP" == "true" ]]; then
  SSH_ARGS+=("--tunnel-through-iap")
fi

if ((${#PASSTHROUGH[@]} > 0)); then
  SSH_ARGS+=("--" "${PASSTHROUGH[@]}")
fi

exec gcloud "${SSH_ARGS[@]}"
