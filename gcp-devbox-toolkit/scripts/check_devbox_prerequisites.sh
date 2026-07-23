#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

PROGRAM_NAME="$(basename "$0")"
VERSION="1.0.0"

MIN_CPU_COUNT="${MIN_CPU_COUNT:-2}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-6}"
MIN_FREE_DISK_GB="${MIN_FREE_DISK_GB:-20}"
REQUIRED_TOOLS="${REQUIRED_TOOLS:-git,docker,dotnet,curl,jq,bash,unzip}"
OPTIONAL_BROWSER_CHECK="${OPTIONAL_BROWSER_CHECK:-true}"
CONFIG_FILE=""

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<EOF
${PROGRAM_NAME} ${VERSION}

Validate a Linux DevBox for containerized and .NET development workloads.

Usage:
  ${PROGRAM_NAME} [options]

Options:
  --config PATH          Load settings from a safe key/value config file.
  --min-cpu COUNT        Minimum logical CPU count.
  --min-memory-gb GB     Minimum memory in GiB.
  --min-free-disk-gb GB  Minimum free space on / in GiB.
  -h, --help             Show this help.
  --version              Show the version.
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
      MIN_CPU_COUNT) MIN_CPU_COUNT="$value" ;;
      MIN_MEMORY_GB) MIN_MEMORY_GB="$value" ;;
      MIN_FREE_DISK_GB) MIN_FREE_DISK_GB="$value" ;;
      REQUIRED_TOOLS) REQUIRED_TOOLS="$value" ;;
      OPTIONAL_BROWSER_CHECK) OPTIONAL_BROWSER_CHECK="$value" ;;
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

tool_version() {
  case "$1" in
    git) git --version 2>/dev/null | head -n 1 ;;
    docker) docker --version 2>/dev/null | head -n 1 ;;
    dotnet) dotnet --version 2>/dev/null | head -n 1 ;;
    curl) curl --version 2>/dev/null | head -n 1 ;;
    jq) jq --version 2>/dev/null | head -n 1 ;;
    bash) bash --version 2>/dev/null | head -n 1 ;;
    unzip) unzip -v 2>/dev/null | head -n 1 ;;
    *) "$1" --version 2>/dev/null | head -n 1 ;;
  esac
}

check_tool() {
  local name="$1"
  local version=""

  if command -v "$name" >/dev/null 2>&1; then
    version="$(tool_version "$name" || true)"
    if [[ -n "$version" ]]; then
      pass "$name is installed: $version"
    else
      pass "$name is installed."
    fi
  else
    fail "$name is not installed or is not on PATH."
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
    --min-cpu) MIN_CPU_COUNT="${2:?ERROR: --min-cpu requires a value}"; shift 2 ;;
    --min-memory-gb) MIN_MEMORY_GB="${2:?ERROR: --min-memory-gb requires a value}"; shift 2 ;;
    --min-free-disk-gb) MIN_FREE_DISK_GB="${2:?ERROR: --min-free-disk-gb requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --version) printf '%s %s\n' "$PROGRAM_NAME" "$VERSION"; exit 0 ;;
    *)
      printf 'ERROR: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

OPTIONAL_BROWSER_CHECK="$(normalize_bool "$OPTIONAL_BROWSER_CHECK")"

for value_name in MIN_CPU_COUNT MIN_MEMORY_GB MIN_FREE_DISK_GB; do
  value="${!value_name}"
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    printf 'ERROR: %s must be a non-negative integer.\n' "$value_name" >&2
    exit 2
  fi
done

printf 'Checking DevBox prerequisites\n\n'

if [[ -r /etc/os-release ]]; then
  OS_PRETTY_NAME="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-unknown}")"
  pass "OS detected: $OS_PRETTY_NAME"
else
  warn "Could not read /etc/os-release."
fi

CPU_COUNT="$(nproc 2>/dev/null || printf '0')"
if ((CPU_COUNT >= MIN_CPU_COUNT)); then
  pass "CPU count is sufficient: $CPU_COUNT"
else
  warn "CPU count is below the configured target: $CPU_COUNT < $MIN_CPU_COUNT"
fi

MEMORY_GB="$(awk '/MemTotal/ { printf "%.0f", $2 / 1024 / 1024 }' /proc/meminfo 2>/dev/null || printf '0')"
if ((MEMORY_GB >= MIN_MEMORY_GB)); then
  pass "Memory is sufficient: ${MEMORY_GB} GiB"
else
  warn "Memory is below the configured target: ${MEMORY_GB} < ${MIN_MEMORY_GB} GiB"
fi

FREE_DISK_GB="$(df -Pk / 2>/dev/null | awk 'NR == 2 { printf "%.0f", $4 / 1024 / 1024 }' || printf '0')"
if ((FREE_DISK_GB >= MIN_FREE_DISK_GB)); then
  pass "Free disk space is sufficient: ${FREE_DISK_GB} GiB"
else
  warn "Free disk space is below the configured target: ${FREE_DISK_GB} < ${MIN_FREE_DISK_GB} GiB"
fi

CURRENT_USER="$(id -un 2>/dev/null || whoami 2>/dev/null || printf 'unknown')"
if [[ "$CURRENT_USER" == "root" ]]; then
  warn "Current user is root. Routine development should use a non-root user."
else
  pass "Current user is non-root: $CURRENT_USER"
fi

IFS=',' read -r -a tools <<< "$REQUIRED_TOOLS"
for tool in "${tools[@]}"; do
  tool="$(trim "$tool")"
  [[ -n "$tool" ]] && check_tool "$tool"
done

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    pass "Docker Compose plugin is available: $(docker compose version 2>/dev/null | head -n 1)"
  else
    fail "Docker Compose plugin is unavailable through 'docker compose'."
  fi

  if docker info >/dev/null 2>&1; then
    pass "Current user can access the Docker daemon."
  else
    fail "Current user cannot access the Docker daemon."
  fi
fi

if [[ "$OPTIONAL_BROWSER_CHECK" == "true" ]]; then
  if command -v chromium >/dev/null 2>&1; then
    pass "Optional Chromium is installed: $(chromium --version 2>/dev/null | head -n 1)"
  elif command -v chromium-browser >/dev/null 2>&1; then
    pass "Optional Chromium is installed: $(chromium-browser --version 2>/dev/null | head -n 1)"
  elif command -v google-chrome >/dev/null 2>&1; then
    pass "Optional Chrome is installed: $(google-chrome --version 2>/dev/null | head -n 1)"
  else
    warn "Optional Chrome or Chromium is not installed."
  fi
fi

printf '\n=== Summary ===\n'
printf 'pass=%s\nwarn=%s\nfail=%s\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"

if ((FAIL_COUNT > 0)); then
  exit 1
fi
