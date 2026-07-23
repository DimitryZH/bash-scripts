#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

PROGRAM_NAME="$(basename "$0")"
VERSION="1.0.0"

EVIDENCE_OUTPUT_DIR="${EVIDENCE_OUTPUT_DIR:-./devbox-evidence}"
VALIDATION_LOG_DIR="${VALIDATION_LOG_DIR:-}"
MAX_LOG_LINES="${MAX_LOG_LINES:-200}"
INCLUDE_DOCKER_DETAILS="${INCLUDE_DOCKER_DETAILS:-true}"
INCLUDE_GIT_STATUS="${INCLUDE_GIT_STATUS:-true}"
CONFIG_FILE=""

usage() {
  cat <<EOF
${PROGRAM_NAME} ${VERSION}

Collect timestamped, read-only DevBox environment evidence.

Usage:
  ${PROGRAM_NAME} [options]

Options:
  --config PATH             Load settings from a safe key/value config file.
  --output-dir PATH         Evidence output directory.
  --validation-log-dir PATH Include tails of *.log and *.txt files.
  --max-log-lines NUMBER    Maximum lines included from each log file.
  --minimal                 Skip detailed Docker and Git status sections.
  -h, --help                Show this help.
  --version                 Show the version.
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
      PROJECT_ID) : ;;
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
      EVIDENCE_OUTPUT_DIR) EVIDENCE_OUTPUT_DIR="$value" ;;
      VALIDATION_LOG_DIR) VALIDATION_LOG_DIR="$value" ;;
      MAX_LOG_LINES) MAX_LOG_LINES="$value" ;;
      INCLUDE_DOCKER_DETAILS) INCLUDE_DOCKER_DETAILS="$value" ;;
      INCLUDE_GIT_STATUS) INCLUDE_GIT_STATUS="$value" ;;
      *)
        printf 'ERROR: unsupported config key at %s:%d: %s\n' \
          "$file" "$line_number" "$key" >&2
        exit 2
        ;;
    esac
  done < "$file"
}

section() {
  printf '\n## %s\n\n' "$1"
}

run_or_note() {
  local executable="$1"
  shift
  if command -v "$executable" >/dev/null 2>&1; then
    "$executable" "$@" 2>&1 || true
  else
    printf '%s is not installed or is not on PATH.\n' "$executable"
  fi
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
    --output-dir) EVIDENCE_OUTPUT_DIR="${2:?ERROR: --output-dir requires a path}"; shift 2 ;;
    --validation-log-dir) VALIDATION_LOG_DIR="${2:?ERROR: --validation-log-dir requires a path}"; shift 2 ;;
    --max-log-lines) MAX_LOG_LINES="${2:?ERROR: --max-log-lines requires a value}"; shift 2 ;;
    --minimal)
      INCLUDE_DOCKER_DETAILS="false"
      INCLUDE_GIT_STATUS="false"
      shift
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

INCLUDE_DOCKER_DETAILS="$(normalize_bool "$INCLUDE_DOCKER_DETAILS")"
INCLUDE_GIT_STATUS="$(normalize_bool "$INCLUDE_GIT_STATUS")"

if [[ ! "$MAX_LOG_LINES" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ERROR: MAX_LOG_LINES must be a positive integer.\n' >&2
  exit 2
fi

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE_OUTPUT_DIR"
EVIDENCE_FILE="$EVIDENCE_OUTPUT_DIR/devbox-evidence-$TIMESTAMP.md"

{
  printf '# Google Cloud DevBox Evidence\n\n'
  printf 'Collected at: `%s`\n\n' "$TIMESTAMP"
  printf 'Hostname: `%s`\n\n' "$(hostname 2>/dev/null || printf 'unknown')"
  printf 'User: `%s`\n' "$(id -un 2>/dev/null || whoami 2>/dev/null || printf 'unknown')"

  section "OS Information"
  if [[ -r /etc/os-release ]]; then
    printf '```text\n'
    cat /etc/os-release
    printf '```\n'
  else
    printf '/etc/os-release is not readable.\n'
  fi
  printf '\n```text\n'
  run_or_note uname -a
  printf '```\n'

  section "Compute Resources"
  printf '```text\n'
  run_or_note nproc
  run_or_note free -h
  run_or_note df -h
  printf '```\n'

  section "Tool Versions"
  printf '```text\n'
  run_or_note git --version
  run_or_note docker --version
  if command -v docker >/dev/null 2>&1; then
    docker compose version 2>&1 || true
  fi
  run_or_note dotnet --info
  run_or_note curl --version
  run_or_note jq --version
  run_or_note bash --version
  run_or_note unzip -v
  printf '```\n'

  if [[ "$INCLUDE_DOCKER_DETAILS" == "true" ]]; then
    section "Docker Information"
    printf '```text\n'
    if command -v docker >/dev/null 2>&1; then
      docker info 2>&1 || true
      printf '\n--- Docker disk usage ---\n'
      docker system df 2>&1 || true
      printf '\n--- Docker containers ---\n'
      docker ps -a 2>&1 || true
    else
      printf 'Docker is not installed.\n'
    fi
    printf '```\n'
  fi

  if [[ "$INCLUDE_GIT_STATUS" == "true" ]]; then
    section "Repository Status"
    printf '```text\n'
    if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
      printf 'Repository root: %s\n' "$(git rev-parse --show-toplevel 2>/dev/null || true)"
      git rev-parse HEAD 2>&1 || true
      git status --short 2>&1 || true
    else
      printf 'Current directory is not inside a Git repository.\n'
    fi
    printf '```\n'
  fi

  section "Validation Logs"
  if [[ -n "$VALIDATION_LOG_DIR" && -d "$VALIDATION_LOG_DIR" ]]; then
    found_logs="false"
    while IFS= read -r -d '' log_file; do
      found_logs="true"
      printf '\n### `%s`\n\n```text\n' "$log_file"
      tail -n "$MAX_LOG_LINES" "$log_file" 2>&1 || true
      printf '```\n'
    done < <(
      find "$VALIDATION_LOG_DIR" -maxdepth 2 -type f \
        \( -name '*.log' -o -name '*.txt' \) -print0 2>/dev/null | sort -z
    )
    if [[ "$found_logs" == "false" ]]; then
      printf 'No matching validation log files were found.\n'
    fi
  else
    printf 'No validation log directory was configured.\n'
  fi
} > "$EVIDENCE_FILE"

printf 'Evidence saved to: %s\n' "$EVIDENCE_FILE"
printf 'Review the file for project identifiers, paths, and operational metadata before publishing it.\n'
