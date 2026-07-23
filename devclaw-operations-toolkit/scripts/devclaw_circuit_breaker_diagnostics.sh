#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PROGRAM_NAME="$(basename "$0")"
VERSION="1.0.0"

PACKAGE_DIR="${DEVCLAW_PACKAGE_DIR:-}"
PACKAGE_SEARCH_ROOT="${DEVCLAW_PACKAGE_SEARCH_ROOT:-/home/devclaw-svc/.openclaw/npm/projects}"
STATE_DIR="${DEVCLAW_STATE_DIR:-/home/devclaw-svc/.openclaw/workspace/devclaw}"
SERVICE_USER="${DEVCLAW_SERVICE_USER:-devclaw-svc}"
GATEWAY_ENV_FILE="${DEVCLAW_GATEWAY_ENV_FILE:-/var/lib/devclaw/gateway/openclaw-gateway.env}"
OPENCLAW_BIN="${OPENCLAW_BIN:-/usr/local/bin/openclaw}"
PROJECT_SLUG="${PROJECT_SLUG:-}"
MAX_RESULTS="${MAX_RESULTS:-120}"
TASK_TIMEOUT_SECONDS="${TASK_TIMEOUT_SECONDS:-120}"
EXACT_ERROR="${EXACT_ERROR:-Execution prevented because the circuit breaker is open}"
MODE="${MODE:-all}"
INCLUDE_TASK_STATUS="${INCLUDE_TASK_STATUS:-false}"
CONFIG_FILE=""

WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<EOF
${PROGRAM_NAME} ${VERSION}

Read-only DevClaw circuit-breaker diagnostics.

Usage:
  ${PROGRAM_NAME} [options]

Options:
  --config PATH                 Load approved settings from a config file.
  --package-dir PATH            DevClaw package directory.
  --package-search-root PATH    Root used to discover the DevClaw package.
  --state-dir PATH              DevClaw state directory.
  --service-user USER           Service account used by OpenClaw/DevClaw.
  --gateway-env-file PATH       Trusted gateway environment file.
  --openclaw-bin PATH           OpenClaw CLI path.
  --project-slug SLUG           DevClaw project slug for tasks_status.
  --mode MODE                   all, source, or state. Default: all.
  --max-results NUMBER          Maximum lines printed per section.
  --task-timeout SECONDS        Timeout passed to OpenClaw agent.
  --exact-error TEXT            Exact error text to search for.
  --include-task-status         Run the optional tasks_status probe.
  --no-task-status              Disable the optional tasks_status probe.
  -h, --help                    Show this help.
  --version                     Show the version.

Default behavior:
  Inspects local DevClaw source and state without invoking an AI agent.
  The tasks_status probe is disabled unless --include-task-status is used.
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

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '[WARN] %s\n' "$*" >&2
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$*" >&2
}

section() {
  printf '\n=== %s ===\n' "$1"
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
      DEVCLAW_PACKAGE_DIR) PACKAGE_DIR="$value" ;;
      DEVCLAW_PACKAGE_SEARCH_ROOT) PACKAGE_SEARCH_ROOT="$value" ;;
      DEVCLAW_STATE_DIR) STATE_DIR="$value" ;;
      DEVCLAW_SERVICE_USER) SERVICE_USER="$value" ;;
      DEVCLAW_GATEWAY_ENV_FILE) GATEWAY_ENV_FILE="$value" ;;
      OPENCLAW_BIN) OPENCLAW_BIN="$value" ;;
      PROJECT_SLUG) PROJECT_SLUG="$value" ;;
      MAX_RESULTS) MAX_RESULTS="$value" ;;
      TASK_TIMEOUT_SECONDS) TASK_TIMEOUT_SECONDS="$value" ;;
      EXACT_ERROR) EXACT_ERROR="$value" ;;
      MODE) MODE="$value" ;;
      INCLUDE_TASK_STATUS) INCLUDE_TASK_STATUS="$(normalize_bool "$value")" ;;
      *)
        printf 'ERROR: unsupported config key at %s:%d: %s\n' \
          "$file" "$line_number" "$key" >&2
        exit 2
        ;;
    esac
  done < "$file"
}

read_env_value() {
  local key_to_find="$1"
  local file="$2"
  local raw line key value

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(trim "$raw")"
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" == export\ * ]]; then
      line="$(trim "${line#export }")"
    fi

    [[ "$line" != *=* ]] && continue
    key="$(trim "${line%%=*}")"

    if [[ "$key" == "$key_to_find" ]]; then
      value="$(trim "${line#*=}")"
      strip_matching_quotes "$value"
      return 0
    fi
  done < "$file"

  return 1
}

print_limited_output() {
  local output="$1"

  if [[ -z "$output" ]]; then
    info "No matches found."
  else
    printf '%s\n' "$output"
  fi
}

discover_package_dir() {
  local -a matches=()

  if [[ -n "$PACKAGE_DIR" ]]; then
    return 0
  fi

  if [[ ! -d "$PACKAGE_SEARCH_ROOT" ]]; then
    fail "Package search root does not exist: $PACKAGE_SEARCH_ROOT"
    return 1
  fi

  mapfile -d '' matches < <(
    find "$PACKAGE_SEARCH_ROOT" \
      -maxdepth 8 \
      -type d \
      -path '*/node_modules/@laurentenhoor/devclaw' \
      -print0 2>/dev/null
  )

  case "${#matches[@]}" in
    0)
      fail "No DevClaw package found under: $PACKAGE_SEARCH_ROOT"
      return 1
      ;;
    1)
      PACKAGE_DIR="${matches[0]}"
      info "Discovered DevClaw package: $PACKAGE_DIR"
      ;;
    *)
      fail "Multiple DevClaw packages found; select one with --package-dir:"
      printf '  %s\n' "${matches[@]}" >&2
      return 1
      ;;
  esac
}

inspect_exact_error() {
  local -a roots=()
  local output=""

  section "Exact error search"

  if [[ "$MODE" == "all" || "$MODE" == "source" ]]; then
    [[ -d "$PACKAGE_DIR" ]] && roots+=("$PACKAGE_DIR")
  fi

  if [[ "$MODE" == "all" || "$MODE" == "state" ]]; then
    [[ -d "$STATE_DIR" ]] && roots+=("$STATE_DIR")
  fi

  if [[ "${#roots[@]}" -eq 0 ]]; then
    warn "No readable search roots are available."
    return 0
  fi

  output="$(
    grep -R -n -F \
      --exclude-dir=node_modules \
      --exclude='*.map' \
      -- "$EXACT_ERROR" "${roots[@]}" 2>/dev/null |
      head -n "$MAX_RESULTS" || true
  )"

  print_limited_output "$output"
}

inspect_source() {
  local index_file="${PACKAGE_DIR}/dist/index.js"
  local output=""

  section "Resilience implementation"

  if [[ ! -d "$PACKAGE_DIR" ]]; then
    fail "DevClaw package directory does not exist: $PACKAGE_DIR"
    return 1
  fi

  if [[ ! -r "$index_file" ]]; then
    fail "Compiled DevClaw entrypoint is not readable: $index_file"
    return 1
  fi

  output="$(
    grep -n -E \
      'circuitBreaker|CircuitBreaker|handleAll|cockatiel|retry|withResilience' \
      "$index_file" 2>/dev/null |
      head -n "$MAX_RESULTS" || true
  )"

  print_limited_output "$output"
}

inspect_state() {
  local -a state_files=()
  local output=""

  section "Circuit-breaker state references"

  if [[ ! -d "$STATE_DIR" ]]; then
    warn "DevClaw state directory does not exist: $STATE_DIR"
    return 0
  fi

  mapfile -d '' state_files < <(
    find "$STATE_DIR" \
      -maxdepth 5 \
      -type f \
      \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.log' \) \
      -print0 2>/dev/null
  )

  if [[ "${#state_files[@]}" -eq 0 ]]; then
    info "No JSON, YAML, or log files found under the state directory."
  else
    output="$(
      grep -n -i -E 'circuit|breaker' "${state_files[@]}" 2>/dev/null |
        head -n "$MAX_RESULTS" || true
    )"
    print_limited_output "$output"
  fi

  section "State file inventory"
  find "$STATE_DIR" -maxdepth 4 -type f -print 2>/dev/null |
    sort |
    head -n "$MAX_RESULTS" || true
}

run_tasks_status() {
  local token=""
  local service_home=""
  local current_user=""
  local message=""
  local -a command=()

  section "DevClaw task status"

  if [[ -z "$PROJECT_SLUG" || "$PROJECT_SLUG" == "REPLACE_WITH_PROJECT_SLUG" ]]; then
    fail "Set --project-slug or PROJECT_SLUG before using --include-task-status."
    return 1
  fi

  if [[ ! -x "$OPENCLAW_BIN" ]]; then
    fail "OpenClaw CLI is not executable: $OPENCLAW_BIN"
    return 1
  fi

  if [[ ! -r "$GATEWAY_ENV_FILE" ]]; then
    fail "Gateway environment file is not readable: $GATEWAY_ENV_FILE"
    return 1
  fi

  token="$(read_env_value "OPENCLAW_GATEWAY_TOKEN" "$GATEWAY_ENV_FILE" || true)"
  if [[ -z "$token" ]]; then
    fail "OPENCLAW_GATEWAY_TOKEN was not found in the gateway environment file."
    return 1
  fi

  if command -v getent >/dev/null 2>&1; then
    service_home="$(getent passwd "$SERVICE_USER" | awk -F: '{print $6}' || true)"
  fi
  service_home="${service_home:-/home/$SERVICE_USER}"
  current_user="$(id -un)"
  message="tasks_status({projectSlug=\"${PROJECT_SLUG}\"})"

  command=(
    env
    "HOME=${service_home}"
    "XDG_CONFIG_HOME=${service_home}/.config"
    "XDG_CACHE_HOME=${service_home}/.cache"
    "XDG_DATA_HOME=${service_home}/.local/share"
    "OPENCLAW_STATE_DIR=${service_home}/.openclaw"
    "OPENCLAW_CONFIG_PATH=${service_home}/.openclaw/openclaw.json"
    "OPENCLAW_NO_COLOR=1"
    "OPENCLAW_GATEWAY_TOKEN=${token}"
    "$OPENCLAW_BIN"
    agent
    --agent main
    --message "$message"
    --json
    --timeout "$TASK_TIMEOUT_SECONDS"
  )

  info "Running tasks_status for project: $PROJECT_SLUG"
  info "This optional probe may invoke an AI model and consume tokens."

  if [[ "$current_user" == "$SERVICE_USER" ]]; then
    if "${command[@]}"; then
      info "tasks_status completed successfully."
    else
      fail "tasks_status failed."
      return 1
    fi
  elif [[ "$EUID" -eq 0 ]] && command -v runuser >/dev/null 2>&1; then
    if runuser -u "$SERVICE_USER" -- "${command[@]}"; then
      info "tasks_status completed successfully."
    else
      fail "tasks_status failed."
      return 1
    fi
  else
    fail "Run as root or as service user '$SERVICE_USER' to execute tasks_status."
    return 1
  fi
}

# Pre-scan only for the config path, so config values can be loaded before
# regular CLI arguments override them.
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
    --config=*)
      CONFIG_FILE="${args[$i]#*=}"
      ;;
  esac
done

if [[ -n "$CONFIG_FILE" ]]; then
  load_config "$CONFIG_FILE"
fi

while (($# > 0)); do
  case "$1" in
    --config)
      shift 2
      ;;
    --config=*)
      shift
      ;;
    --package-dir)
      PACKAGE_DIR="${2:?ERROR: --package-dir requires a path}"
      shift 2
      ;;
    --package-search-root)
      PACKAGE_SEARCH_ROOT="${2:?ERROR: --package-search-root requires a path}"
      shift 2
      ;;
    --state-dir)
      STATE_DIR="${2:?ERROR: --state-dir requires a path}"
      shift 2
      ;;
    --service-user)
      SERVICE_USER="${2:?ERROR: --service-user requires a user}"
      shift 2
      ;;
    --gateway-env-file)
      GATEWAY_ENV_FILE="${2:?ERROR: --gateway-env-file requires a path}"
      shift 2
      ;;
    --openclaw-bin)
      OPENCLAW_BIN="${2:?ERROR: --openclaw-bin requires a path}"
      shift 2
      ;;
    --project-slug)
      PROJECT_SLUG="${2:?ERROR: --project-slug requires a value}"
      shift 2
      ;;
    --mode)
      MODE="${2:?ERROR: --mode requires a value}"
      shift 2
      ;;
    --max-results)
      MAX_RESULTS="${2:?ERROR: --max-results requires a number}"
      shift 2
      ;;
    --task-timeout)
      TASK_TIMEOUT_SECONDS="${2:?ERROR: --task-timeout requires seconds}"
      shift 2
      ;;
    --exact-error)
      EXACT_ERROR="${2:?ERROR: --exact-error requires text}"
      shift 2
      ;;
    --include-task-status)
      INCLUDE_TASK_STATUS="true"
      shift
      ;;
    --no-task-status)
      INCLUDE_TASK_STATUS="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --version)
      printf '%s %s\n' "$PROGRAM_NAME" "$VERSION"
      exit 0
      ;;
    *)
      printf 'ERROR: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

INCLUDE_TASK_STATUS="$(normalize_bool "$INCLUDE_TASK_STATUS")"

case "$MODE" in
  all|source|state) ;;
  *)
    printf 'ERROR: --mode must be all, source, or state.\n' >&2
    exit 2
    ;;
esac

if [[ ! "$MAX_RESULTS" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ERROR: MAX_RESULTS must be a positive integer.\n' >&2
  exit 2
fi

if [[ ! "$TASK_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ERROR: TASK_TIMEOUT_SECONDS must be a positive integer.\n' >&2
  exit 2
fi

for dependency in grep find sort head id awk; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'ERROR: required command is unavailable: %s\n' "$dependency" >&2
    exit 2
  fi
done

section "Execution context"
printf 'mode=%s\n' "$MODE"
printf 'state_dir=%s\n' "$STATE_DIR"
printf 'service_user=%s\n' "$SERVICE_USER"
printf 'include_task_status=%s\n' "$INCLUDE_TASK_STATUS"
printf 'max_results=%s\n' "$MAX_RESULTS"

if [[ "$MODE" == "all" || "$MODE" == "source" ]]; then
  discover_package_dir || true
  printf 'package_dir=%s\n' "${PACKAGE_DIR:-not-found}"
fi

inspect_exact_error

if [[ "$MODE" == "all" || "$MODE" == "source" ]]; then
  inspect_source || true
fi

if [[ "$MODE" == "all" || "$MODE" == "state" ]]; then
  inspect_state
fi

if [[ "$INCLUDE_TASK_STATUS" == "true" ]]; then
  run_tasks_status || true
else
  section "DevClaw task status"
  info "Skipped. Use --include-task-status and set a project slug to enable it."
fi

section "Summary"
printf 'warnings=%d\n' "$WARN_COUNT"
printf 'failures=%d\n' "$FAIL_COUNT"

if ((FAIL_COUNT > 0)); then
  printf 'result=FAIL\n'
  exit 1
fi

if ((WARN_COUNT > 0)); then
  printf 'result=PASS_WITH_WARNINGS\n'
  exit 0
fi

printf 'result=PASS\n'
