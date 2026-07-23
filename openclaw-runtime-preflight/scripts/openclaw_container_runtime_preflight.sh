#!/usr/bin/env bash

# Read-only runtime preflight for a systemd-managed, containerized OpenClaw deployment.
# The script does not restart services, modify containers, or change runtime state.

set -uo pipefail
shopt -s extglob

SCRIPT_NAME="$(basename "$0")"
MODE="${MODE:-basic}"
CONFIG_FILE=""
CLI_MODE=""

SERVICE_NAME="${SERVICE_NAME:-openclaw.service}"
CONTAINER_NAME="${CONTAINER_NAME:-openclaw-gateway}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
STATE_MOUNT="${STATE_MOUNT:-/var/lib/openclaw}"
STATE_DIR="${STATE_DIR:-/var/lib/openclaw/state}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/var/lib/openclaw/workspace}"
TOKEN_FILE="${TOKEN_FILE:-/run/openclaw/secrets/OPENCLAW_GATEWAY_TOKEN}"
MODEL_NAME="${MODEL_NAME:-openclaw}"
CONTROL_UI_PATTERN="${CONTROL_UI_PATTERN:-openclaw-control-ui}"
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-3}"
CURL_MAX_TIME="${CURL_MAX_TIME:-15}"
CHAT_MAX_TIME="${CHAT_MAX_TIME:-120}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
GATEWAY_TOKEN=""

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [options]

Options:
  --mode basic|deep   Validation depth. Default: basic
  --config FILE       Load values from a trusted KEY=VALUE config file
  -h, --help          Show this help message

Modes:
  basic  Validate service, container, storage, health, and readiness.
  deep   Run basic checks plus authenticated model, chat, and admin RPC checks.

Environment variables:
  SERVICE_NAME, CONTAINER_NAME, BASE_URL, STATE_MOUNT, STATE_DIR,
  WORKSPACE_DIR, TOKEN_FILE, MODEL_NAME, CONTROL_UI_PATTERN,
  CURL_CONNECT_TIMEOUT, CURL_MAX_TIME, CHAT_MAX_TIME
USAGE
}

trim() {
  local value="$1"
  value="${value##+([[:space:]])}"
  value="${value%%+([[:space:]])}"
  printf '%s' "$value"
}

is_allowed_config_key() {
  case "$1" in
    MODE|SERVICE_NAME|CONTAINER_NAME|BASE_URL|STATE_MOUNT|STATE_DIR|WORKSPACE_DIR|TOKEN_FILE|MODEL_NAME|CONTROL_UI_PATTERN|CURL_CONNECT_TIMEOUT|CURL_MAX_TIME|CHAT_MAX_TIME)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

load_config() {
  local file="$1"
  local raw line key value

  if [[ ! -r "$file" ]]; then
    printf 'ERROR: Config file is not readable: %s\n' "$file" >&2
    exit 2
  fi

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%$'\r'}"
    line="$(trim "$line")"

    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ ! "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      printf 'WARN: Ignoring malformed config line: %s\n' "$line" >&2
      continue
    fi

    key="${BASH_REMATCH[1]}"
    value="$(trim "${BASH_REMATCH[2]}")"

    if ! is_allowed_config_key "$key"; then
      printf 'WARN: Ignoring unsupported config key: %s\n' "$key" >&2
      continue
    fi

    if [[ ${#value} -ge 2 ]]; then
      if [[ "$value" == \"*\" && "$value" == *\" ]]; then
        value="${value:1:${#value}-2}"
      elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
        value="${value:1:${#value}-2}"
      fi
    fi

    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"
}

pass() {
  printf '[PASS] %s\n' "$*"
  ((PASS_COUNT += 1))
}

warn() {
  printf '[WARN] %s\n' "$*"
  ((WARN_COUNT += 1))
}

fail() {
  printf '[FAIL] %s\n' "$*"
  ((FAIL_COUNT += 1))
}

info() {
  printf '[INFO] %s\n' "$*"
}

require_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "Dependency available: $command_name"
  else
    fail "Required command not found: $command_name"
  fi
}

curl_code() {
  local url="$1"
  curl --silent --show-error \
    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    --output /dev/null \
    --write-out '%{http_code}' \
    "$url"
}

check_http_endpoint() {
  local label="$1"
  local url="$2"
  local expected_code="$3"
  local code

  if code="$(curl_code "$url")"; then
    if [[ "$code" == "$expected_code" ]]; then
      pass "$label returned HTTP $code"
    else
      fail "$label returned HTTP $code; expected $expected_code"
    fi
  else
    fail "$label request failed: $url"
  fi
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --mode)
        [[ $# -ge 2 ]] || { printf 'ERROR: --mode requires a value.\n' >&2; exit 2; }
        CLI_MODE="$2"
        shift 2
        ;;
      --config)
        [[ $# -ge 2 ]] || { printf 'ERROR: --config requires a file path.\n' >&2; exit 2; }
        CONFIG_FILE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'ERROR: Unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
}

check_dependencies() {
  local dependencies=(systemctl docker curl findmnt stat grep)
  local dependency

  if [[ "$MODE" == "deep" ]]; then
    dependencies+=(jq)
  fi

  printf '\n== Dependencies ==\n'
  for dependency in "${dependencies[@]}"; do
    require_command "$dependency"
  done

  if ((FAIL_COUNT > 0)); then
    printf '\nDependency validation failed; runtime checks were not started.\n'
    print_summary
    exit 1
  fi
}

check_service() {
  local state

  printf '\n== systemd service ==\n'

  if state="$(systemctl is-active "$SERVICE_NAME" 2>&1)" && [[ "$state" == "active" ]]; then
    pass "$SERVICE_NAME is active"
  else
    fail "$SERVICE_NAME is not active (${state:-unknown})"
  fi

  if state="$(systemctl is-enabled "$SERVICE_NAME" 2>&1)" && [[ "$state" == "enabled" ]]; then
    pass "$SERVICE_NAME is enabled"
  else
    fail "$SERVICE_NAME is not enabled (${state:-unknown})"
  fi
}

check_container() {
  local all_names names container_count image_ref image_id

  printf '\n== Container runtime ==\n'

  if ! all_names="$(docker ps --format '{{.Names}}' 2>/dev/null)"; then
    fail "Unable to list running Docker containers"
    return
  fi

  names="$(printf '%s\n' "$all_names" | grep -Fx "$CONTAINER_NAME" || true)"
  if [[ -n "$names" ]]; then
    container_count="$(printf '%s\n' "$names" | grep -c .)"
  else
    container_count=0
  fi

  if [[ "$container_count" == "1" ]]; then
    pass "Exactly one running container named $CONTAINER_NAME"
  else
    fail "Expected one running container named $CONTAINER_NAME; found $container_count"
    return
  fi

  if image_ref="$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}' 2>/dev/null)"; then
    pass "Container image reference: $image_ref"
  else
    fail "Unable to read container image reference"
  fi

  if image_id="$(docker inspect "$CONTAINER_NAME" --format '{{.Image}}' 2>/dev/null)"; then
    pass "Container image ID: $image_id"
  else
    fail "Unable to read container image ID"
  fi
}

check_storage() {
  local mount_info metadata

  printf '\n== Persistent storage ==\n'

  if mount_info="$(findmnt -n -o SOURCE,FSTYPE,TARGET "$STATE_MOUNT" 2>/dev/null)"; then
    pass "Persistent mount detected: $mount_info"
  else
    fail "No mount detected at $STATE_MOUNT"
  fi

  if metadata="$(stat -c '%u:%g %a %n' "$STATE_DIR" 2>/dev/null)"; then
    pass "State directory metadata: $metadata"
  else
    fail "Unable to inspect state directory: $STATE_DIR"
  fi

  if metadata="$(stat -c '%u:%g %a %n' "$WORKSPACE_DIR" 2>/dev/null)"; then
    pass "Workspace directory metadata: $metadata"
  else
    fail "Unable to inspect workspace directory: $WORKSPACE_DIR"
  fi
}

check_http() {
  printf '\n== HTTP probes ==\n'
  check_http_endpoint "Health endpoint" "${BASE_URL%/}/health" "200"
  check_http_endpoint "Readiness endpoint" "${BASE_URL%/}/readyz" "200"
}

read_token() {
  if [[ ! -r "$TOKEN_FILE" ]]; then
    fail "Gateway token file is not readable: $TOKEN_FILE"
    return 1
  fi

  IFS= read -r GATEWAY_TOKEN < "$TOKEN_FILE" || true
  GATEWAY_TOKEN="${GATEWAY_TOKEN//$'\r'/}"

  if [[ -z "$GATEWAY_TOKEN" ]]; then
    fail "Gateway token file is empty: $TOKEN_FILE"
    return 1
  fi
}

check_deep_api() {
  local models_json models_count chat_payload chat_json chat_ok admin_json
  local admin_ok pending_count paired_count control_ui_present

  printf '\n== Authenticated API checks ==\n'

  if ! read_token; then
    return
  fi
  pass "Gateway token loaded from protected file"

  if models_json="$(curl --silent --show-error \
      --connect-timeout "$CURL_CONNECT_TIMEOUT" \
      --max-time "$CURL_MAX_TIME" \
      --fail \
      --header "Authorization: Bearer $GATEWAY_TOKEN" \
      "${BASE_URL%/}/v1/models")"; then
    models_count="$(printf '%s' "$models_json" | jq -r 'if (.data | type) == "array" then (.data | length) else -1 end' 2>/dev/null || printf '%s' -1)"
    if [[ "$models_count" =~ ^[0-9]+$ ]] && ((models_count >= 0)); then
      pass "Authenticated models endpoint returned $models_count model(s)"
    else
      fail "Models endpoint did not return the expected JSON structure"
    fi
  else
    fail "Authenticated models request failed"
  fi

  info "The next check sends a real chat completion request."
  chat_payload="$(jq -nc --arg model "$MODEL_NAME" '{model:$model,messages:[{role:"user",content:"Reply with exactly READY."}]}')"

  if chat_json="$(curl --silent --show-error \
      --connect-timeout "$CURL_CONNECT_TIMEOUT" \
      --max-time "$CHAT_MAX_TIME" \
      --fail \
      --header "Authorization: Bearer $GATEWAY_TOKEN" \
      --header 'Content-Type: application/json' \
      --data "$chat_payload" \
      "${BASE_URL%/}/v1/chat/completions")"; then
    chat_ok="$(printf '%s' "$chat_json" | jq -r 'if ((.choices | type) == "array" and (.choices | length) > 0 and (.choices[0].message.content | type) == "string") then "yes" else "no" end' 2>/dev/null || printf '%s' no)"
    if [[ "$chat_ok" == "yes" ]]; then
      pass "Chat completion returned a valid assistant message"
    else
      fail "Chat completion response did not match the expected JSON structure"
    fi
  else
    fail "Chat completion request failed"
  fi

  if admin_json="$(curl --silent --show-error \
      --connect-timeout "$CURL_CONNECT_TIMEOUT" \
      --max-time "$CURL_MAX_TIME" \
      --fail \
      --header "Authorization: Bearer $GATEWAY_TOKEN" \
      --header 'Content-Type: application/json' \
      --data '{"method":"device.pair.list","params":{}}' \
      "${BASE_URL%/}/api/v1/admin/rpc")"; then
    admin_ok="$(printf '%s' "$admin_json" | jq -r 'if ((.ok // false) == true or .result != null) then "yes" else "no" end' 2>/dev/null || printf '%s' no)"
    if [[ "$admin_ok" == "yes" ]]; then
      pass "Admin RPC returned a valid response"
    else
      fail "Admin RPC response did not indicate success"
    fi

    pending_count="$(printf '%s' "$admin_json" | jq -r '((.result.pending // .pending // []) | length)' 2>/dev/null || printf '%s' unknown)"
    paired_count="$(printf '%s' "$admin_json" | jq -r '((.result.paired // .paired // []) | length)' 2>/dev/null || printf '%s' unknown)"
    control_ui_present="$(printf '%s' "$admin_json" | jq -r --arg pattern "$CONTROL_UI_PATTERN" 'if any((.result.paired // .paired // [])[]?; (tostring | test($pattern))) then "yes" else "no" end' 2>/dev/null || printf '%s' no)"

    info "Pending device count: $pending_count"
    info "Paired device count: $paired_count"
    if [[ "$control_ui_present" == "yes" ]]; then
      pass "Paired device matching '$CONTROL_UI_PATTERN' is present"
    else
      warn "No paired device matching '$CONTROL_UI_PATTERN' was found"
    fi
  else
    fail "Admin RPC request failed"
  fi
}

print_context() {
  printf 'OpenClaw container runtime preflight\n'
  printf 'Mode: %s\n' "$MODE"
  printf 'Service: %s\n' "$SERVICE_NAME"
  printf 'Container: %s\n' "$CONTAINER_NAME"
  printf 'Base URL: %s\n' "$BASE_URL"
  printf 'State mount: %s\n' "$STATE_MOUNT"
  if [[ -n "$CONFIG_FILE" ]]; then
    printf 'Config: %s\n' "$CONFIG_FILE"
  else
    printf 'Config: built-in defaults and environment variables\n'
  fi
}

print_summary() {
  printf '\n== Summary ==\n'
  printf 'PASS=%d WARN=%d FAIL=%d\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"

  if ((FAIL_COUNT == 0)); then
    printf 'RESULT=PASS\n'
  else
    printf 'RESULT=FAIL\n'
  fi
}

main() {
  parse_args "$@"

  if [[ -n "$CONFIG_FILE" ]]; then
    load_config "$CONFIG_FILE"
  fi

  if [[ -n "$CLI_MODE" ]]; then
    MODE="$CLI_MODE"
  fi

  case "$MODE" in
    basic|deep) ;;
    *)
      printf 'ERROR: Unsupported mode: %s\n' "$MODE" >&2
      usage >&2
      exit 2
      ;;
  esac

  print_context
  check_dependencies
  check_service
  check_container
  check_storage
  check_http

  if [[ "$MODE" == "deep" ]]; then
    check_deep_api
  fi

  print_summary

  if ((FAIL_COUNT > 0)); then
    exit 1
  fi
}

main "$@"
