#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PROGRAM_NAME="$(basename "$0")"
VERSION="1.0.0"

PROJECT_ID="${PROJECT_ID:-REPLACE_WITH_GCP_PROJECT_ID}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-ai-devbox-01}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-2}"
BOOT_DISK_SIZE_GB="${BOOT_DISK_SIZE_GB:-80}"
BOOT_DISK_TYPE="${BOOT_DISK_TYPE:-pd-balanced}"
IMAGE_FAMILY="${IMAGE_FAMILY:-ubuntu-2404-lts-amd64}"
IMAGE_PROJECT="${IMAGE_PROJECT:-ubuntu-os-cloud}"
NETWORK="${NETWORK:-default}"
SUBNET="${SUBNET:-default}"
NETWORK_TAGS="${NETWORK_TAGS:-devbox-iap-ssh}"
CREATE_EXTERNAL_IP="${CREATE_EXTERNAL_IP:-false}"
IAP_ALLOW_FIREWALL_RULE="${IAP_ALLOW_FIREWALL_RULE:-devbox-allow-iap-ssh}"
PUBLIC_SSH_DENY_FIREWALL_RULE="${PUBLIC_SSH_DENY_FIREWALL_RULE:-devbox-deny-public-ssh}"
REQUIRE_IAP_FIREWALL_RULE="${REQUIRE_IAP_FIREWALL_RULE:-true}"
REQUIRE_PUBLIC_SSH_DENY_RULE="${REQUIRE_PUBLIC_SSH_DENY_RULE:-true}"
ENABLE_OS_LOGIN="${ENABLE_OS_LOGIN:-true}"
NO_SERVICE_ACCOUNT="${NO_SERVICE_ACCOUNT:-true}"
LABELS="${LABELS:-purpose=devbox,managed-by=bash}"

CONFIG_FILE=""
DRY_RUN="false"
ASSUME_YES="false"

usage() {
  cat <<EOF
${PROGRAM_NAME} ${VERSION}

Create a hardened Google Compute Engine DevBox.

Usage:
  ${PROGRAM_NAME} [options]

Options:
  --config PATH                Load settings from a safe key/value config file.
  --project-id ID              Google Cloud project ID.
  --region REGION              Region used for subnet validation.
  --zone ZONE                  Compute Engine zone.
  --vm-name NAME               VM instance name.
  --machine-type TYPE          Compute Engine machine type.
  --external-ip                Attach an ephemeral external IP.
  --no-external-ip             Do not attach an external IP (default).
  --dry-run                    Print the gcloud command without creating a VM.
  --yes                        Skip the interactive confirmation.
  -h, --help                   Show this help.
  --version                    Show the version.

The script does not create firewall rules, networks, subnets, service accounts,
or APIs. Required prerequisites must already exist.
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
      REGION) REGION="$value" ;;
      ZONE) ZONE="$value" ;;
      VM_NAME) VM_NAME="$value" ;;
      MACHINE_TYPE) MACHINE_TYPE="$value" ;;
      BOOT_DISK_SIZE_GB) BOOT_DISK_SIZE_GB="$value" ;;
      BOOT_DISK_TYPE) BOOT_DISK_TYPE="$value" ;;
      IMAGE_FAMILY) IMAGE_FAMILY="$value" ;;
      IMAGE_PROJECT) IMAGE_PROJECT="$value" ;;
      NETWORK) NETWORK="$value" ;;
      SUBNET) SUBNET="$value" ;;
      NETWORK_TAGS) NETWORK_TAGS="$value" ;;
      CREATE_EXTERNAL_IP) CREATE_EXTERNAL_IP="$value" ;;
      IAP_ALLOW_FIREWALL_RULE) IAP_ALLOW_FIREWALL_RULE="$value" ;;
      PUBLIC_SSH_DENY_FIREWALL_RULE) PUBLIC_SSH_DENY_FIREWALL_RULE="$value" ;;
      REQUIRE_IAP_FIREWALL_RULE) REQUIRE_IAP_FIREWALL_RULE="$value" ;;
      REQUIRE_PUBLIC_SSH_DENY_RULE) REQUIRE_PUBLIC_SSH_DENY_RULE="$value" ;;
      ENABLE_OS_LOGIN) ENABLE_OS_LOGIN="$value" ;;
      NO_SERVICE_ACCOUNT) NO_SERVICE_ACCOUNT="$value" ;;
      LABELS) LABELS="$value" ;;
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

print_command() {
  printf 'gcloud'
  printf ' %q' "$@"
  printf '\n'
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
    --region) REGION="${2:?ERROR: --region requires a value}"; shift 2 ;;
    --zone) ZONE="${2:?ERROR: --zone requires a value}"; shift 2 ;;
    --vm-name) VM_NAME="${2:?ERROR: --vm-name requires a value}"; shift 2 ;;
    --machine-type) MACHINE_TYPE="${2:?ERROR: --machine-type requires a value}"; shift 2 ;;
    --external-ip) CREATE_EXTERNAL_IP="true"; shift ;;
    --no-external-ip) CREATE_EXTERNAL_IP="false"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --yes) ASSUME_YES="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    --version) printf '%s %s\n' "$PROGRAM_NAME" "$VERSION"; exit 0 ;;
    *)
      printf 'ERROR: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

CREATE_EXTERNAL_IP="$(normalize_bool "$CREATE_EXTERNAL_IP")"
REQUIRE_IAP_FIREWALL_RULE="$(normalize_bool "$REQUIRE_IAP_FIREWALL_RULE")"
REQUIRE_PUBLIC_SSH_DENY_RULE="$(normalize_bool "$REQUIRE_PUBLIC_SSH_DENY_RULE")"
ENABLE_OS_LOGIN="$(normalize_bool "$ENABLE_OS_LOGIN")"
NO_SERVICE_ACCOUNT="$(normalize_bool "$NO_SERVICE_ACCOUNT")"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "REPLACE_WITH_GCP_PROJECT_ID" ]]; then
  printf 'ERROR: set PROJECT_ID before creating a DevBox.\n' >&2
  exit 2
fi

if [[ ! "$BOOT_DISK_SIZE_GB" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ERROR: BOOT_DISK_SIZE_GB must be a positive integer.\n' >&2
  exit 2
fi

if ! command -v gcloud >/dev/null 2>&1; then
  printf 'ERROR: gcloud is not installed or is not on PATH.\n' >&2
  exit 2
fi

printf '=== Google Cloud DevBox configuration ===\n'
printf 'project=%s\nregion=%s\nzone=%s\nvm_name=%s\n' "$PROJECT_ID" "$REGION" "$ZONE" "$VM_NAME"
printf 'machine_type=%s\nboot_disk=%sGB %s\n' "$MACHINE_TYPE" "$BOOT_DISK_SIZE_GB" "$BOOT_DISK_TYPE"
printf 'image=%s/%s\nnetwork=%s\nsubnet=%s\n' "$IMAGE_PROJECT" "$IMAGE_FAMILY" "$NETWORK" "$SUBNET"
printf 'network_tags=%s\nexternal_ip=%s\nos_login=%s\n' "$NETWORK_TAGS" "$CREATE_EXTERNAL_IP" "$ENABLE_OS_LOGIN"
printf 'service_account=%s\nlabels=%s\n\n' "$([[ "$NO_SERVICE_ACCOUNT" == "true" ]] && printf 'none' || printf 'default')" "$LABELS"

if ! gcloud projects describe "$PROJECT_ID" --format='value(projectId)' >/dev/null 2>&1; then
  printf 'ERROR: project is not accessible: %s\n' "$PROJECT_ID" >&2
  exit 1
fi

if gcloud compute instances describe "$VM_NAME" --project "$PROJECT_ID" --zone "$ZONE" >/dev/null 2>&1; then
  printf 'ERROR: VM already exists: %s in %s/%s\n' "$VM_NAME" "$PROJECT_ID" "$ZONE" >&2
  printf 'The script will not modify or replace an existing VM.\n' >&2
  exit 1
fi

if ! gcloud compute networks describe "$NETWORK" --project "$PROJECT_ID" >/dev/null 2>&1; then
  printf 'ERROR: network does not exist or is not accessible: %s\n' "$NETWORK" >&2
  exit 1
fi

if [[ -n "$SUBNET" ]]; then
  if ! gcloud compute networks subnets describe "$SUBNET" \
      --project "$PROJECT_ID" --region "$REGION" >/dev/null 2>&1; then
    printf 'ERROR: subnet does not exist in region %s: %s\n' "$REGION" "$SUBNET" >&2
    exit 1
  fi
fi

if [[ "$REQUIRE_IAP_FIREWALL_RULE" == "true" ]]; then
  if ! gcloud compute firewall-rules describe "$IAP_ALLOW_FIREWALL_RULE" \
      --project "$PROJECT_ID" >/dev/null 2>&1; then
    printf 'ERROR: required IAP SSH firewall rule is missing: %s\n' "$IAP_ALLOW_FIREWALL_RULE" >&2
    exit 1
  fi
fi

if [[ "$CREATE_EXTERNAL_IP" == "true" && "$REQUIRE_PUBLIC_SSH_DENY_RULE" == "true" ]]; then
  if ! gcloud compute firewall-rules describe "$PUBLIC_SSH_DENY_FIREWALL_RULE" \
      --project "$PROJECT_ID" >/dev/null 2>&1; then
    printf 'ERROR: external IP requested but public SSH deny rule is missing: %s\n' \
      "$PUBLIC_SSH_DENY_FIREWALL_RULE" >&2
    exit 1
  fi
fi

CREATE_ARGS=(
  compute instances create "$VM_NAME"
  "--project=$PROJECT_ID"
  "--zone=$ZONE"
  "--machine-type=$MACHINE_TYPE"
  "--image-family=$IMAGE_FAMILY"
  "--image-project=$IMAGE_PROJECT"
  "--boot-disk-size=${BOOT_DISK_SIZE_GB}GB"
  "--boot-disk-type=$BOOT_DISK_TYPE"
  "--network=$NETWORK"
  "--metadata=enable-oslogin=$ENABLE_OS_LOGIN"
  "--labels=$LABELS"
  "--maintenance-policy=MIGRATE"
  "--provisioning-model=STANDARD"
  "--shielded-secure-boot"
  "--shielded-vtpm"
  "--shielded-integrity-monitoring"
)

if [[ -n "$SUBNET" ]]; then
  CREATE_ARGS+=("--subnet=$SUBNET")
fi

if [[ -n "$NETWORK_TAGS" ]]; then
  CREATE_ARGS+=("--tags=$NETWORK_TAGS")
fi

if [[ "$CREATE_EXTERNAL_IP" == "false" ]]; then
  CREATE_ARGS+=("--no-address")
fi

if [[ "$NO_SERVICE_ACCOUNT" == "true" ]]; then
  CREATE_ARGS+=("--no-service-account" "--no-scopes")
fi

if [[ "$DRY_RUN" == "true" ]]; then
  printf '=== Dry run ===\n'
  print_command "${CREATE_ARGS[@]}"
  exit 0
fi

printf 'This operation creates a billable Google Cloud VM.\n'
if [[ "$CREATE_EXTERNAL_IP" == "false" ]]; then
  printf 'No external IP will be attached. Ensure Cloud NAT or another approved outbound path exists if internet access is required.\n'
fi

if [[ "$ASSUME_YES" != "true" ]]; then
  read -r -p "Type 'create' to continue: " confirmation
  if [[ "$confirmation" != "create" ]]; then
    printf 'Canceled. No resources were created.\n'
    exit 0
  fi
fi

gcloud "${CREATE_ARGS[@]}"

printf '\nDevBox creation requested successfully.\n'
printf 'Next step: ./scripts/connect_gce_devbox.sh --config <your-config>\n'
