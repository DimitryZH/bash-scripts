#!/usr/bin/env bash
set -euo pipefail

# Dry-run dataset cleanup script for FinOps validation.
# Deletes only the deterministic resources created by gcloud_commands.sh.
#
# Required environment variables:
# - TARGET_PROJECT_A
# - TARGET_PROJECT_B

TARGET_PROJECT_A="${TARGET_PROJECT_A:-REPLACE_WITH_TARGET_PROJECT_A}"
TARGET_PROJECT_B="${TARGET_PROJECT_B:-REPLACE_WITH_TARGET_PROJECT_B}"

REGION_A="us-central1"

VM_1="finops-dr-vm-stopped-01"
VM_2="finops-dr-vm-stopped-02"

DISK_1="finops-dr-disk-unattached-01"
DISK_2="finops-dr-disk-unattached-02"

IP_REG_1="finops-dr-ip-unused-reg-01"
IP_GLB_1="finops-dr-ip-unused-glb-01"

DELETED_COUNT=0
MISSING_COUNT=0
FAILED_COUNT=0

if [[ "$TARGET_PROJECT_A" == REPLACE_WITH_TARGET_PROJECT_A || "$TARGET_PROJECT_B" == REPLACE_WITH_TARGET_PROJECT_B ]]; then
  echo "Set TARGET_PROJECT_A and TARGET_PROJECT_B environment variables before running."
  exit 1
fi

echo "=== Dry-run Dataset Cleanup: Starting ==="
echo "Target project A: ${TARGET_PROJECT_A}"
echo "Target project B: ${TARGET_PROJECT_B}"
echo

get_instance_zone() {
  local project_id="$1"
  local instance_name="$2"
  gcloud compute instances list \
    --project="${project_id}" \
    --filter="name=${instance_name}" \
    --format="value(zone)" | head -n 1
}

get_disk_zone() {
  local project_id="$1"
  local disk_name="$2"
  gcloud compute disks list \
    --project="${project_id}" \
    --filter="name=${disk_name}" \
    --format="value(zone)" | head -n 1
}

delete_vm_if_exists() {
  local project_id="$1"
  local vm_name="$2"
  local zone

  zone="$(get_instance_zone "${project_id}" "${vm_name}")"
  if [[ -z "${zone}" ]]; then
    echo "VM ${vm_name} not found in ${project_id}; skipping."
    MISSING_COUNT=$((MISSING_COUNT + 1))
    return
  fi

  zone="${zone##*/}"
  echo "Deleting VM ${vm_name} in ${project_id} (${zone})..."
  if gcloud compute instances delete "${vm_name}" --project="${project_id}" --zone="${zone}" --quiet; then
    DELETED_COUNT=$((DELETED_COUNT + 1))
  else
    echo "WARNING: Failed to delete VM ${vm_name} in ${project_id} (${zone})."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
}

delete_disk_if_exists() {
  local project_id="$1"
  local disk_name="$2"
  local zone

  zone="$(get_disk_zone "${project_id}" "${disk_name}")"
  if [[ -z "${zone}" ]]; then
    echo "Disk ${disk_name} not found in ${project_id}; skipping."
    MISSING_COUNT=$((MISSING_COUNT + 1))
    return
  fi

  zone="${zone##*/}"
  echo "Deleting disk ${disk_name} in ${project_id} (${zone})..."
  if gcloud compute disks delete "${disk_name}" --project="${project_id}" --zone="${zone}" --quiet; then
    DELETED_COUNT=$((DELETED_COUNT + 1))
  else
    echo "WARNING: Failed to delete disk ${disk_name} in ${project_id} (${zone})."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
}

delete_regional_ip_if_exists() {
  local project_id="$1"
  local ip_name="$2"
  local exists

  exists="$(gcloud compute addresses list \
    --project="${project_id}" \
    --regions="${REGION_A}" \
    --filter="name=${ip_name}" \
    --format="value(name)" | head -n 1)"

  if [[ -z "${exists}" ]]; then
    echo "Regional IP ${ip_name} not found in ${project_id} (${REGION_A}); skipping."
    MISSING_COUNT=$((MISSING_COUNT + 1))
    return
  fi

  echo "Deleting regional IP ${ip_name} in ${project_id} (${REGION_A})..."
  if gcloud compute addresses delete "${ip_name}" --project="${project_id}" --region="${REGION_A}" --quiet; then
    DELETED_COUNT=$((DELETED_COUNT + 1))
  else
    echo "WARNING: Failed to delete regional IP ${ip_name} in ${project_id} (${REGION_A})."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
}

delete_global_ip_if_exists() {
  local project_id="$1"
  local ip_name="$2"
  local exists

  exists="$(gcloud compute addresses list \
    --project="${project_id}" \
    --global \
    --filter="name=${ip_name}" \
    --format="value(name)" | head -n 1)"

  if [[ -z "${exists}" ]]; then
    echo "Global IP ${ip_name} not found in ${project_id}; skipping."
    MISSING_COUNT=$((MISSING_COUNT + 1))
    return
  fi

  echo "Deleting global IP ${ip_name} in ${project_id}..."
  if gcloud compute addresses delete "${ip_name}" --project="${project_id}" --global --quiet; then
    DELETED_COUNT=$((DELETED_COUNT + 1))
  else
    echo "WARNING: Failed to delete global IP ${ip_name} in ${project_id}."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
}

verify_absent_instance() {
  local project_id="$1"
  local vm_name="$2"
  local found
  found="$(get_instance_zone "${project_id}" "${vm_name}")"
  if [[ -n "${found}" ]]; then
    echo "VERIFY FAIL: VM ${vm_name} still exists in ${project_id}."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  else
    echo "VERIFY OK: VM ${vm_name} absent in ${project_id}."
  fi
}

verify_absent_disk() {
  local project_id="$1"
  local disk_name="$2"
  local found
  found="$(get_disk_zone "${project_id}" "${disk_name}")"
  if [[ -n "${found}" ]]; then
    echo "VERIFY FAIL: Disk ${disk_name} still exists in ${project_id}."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  else
    echo "VERIFY OK: Disk ${disk_name} absent in ${project_id}."
  fi
}

verify_absent_regional_ip() {
  local project_id="$1"
  local ip_name="$2"
  local found
  found="$(gcloud compute addresses list \
    --project="${project_id}" \
    --regions="${REGION_A}" \
    --filter="name=${ip_name}" \
    --format="value(name)" | head -n 1)"
  if [[ -n "${found}" ]]; then
    echo "VERIFY FAIL: Regional IP ${ip_name} still exists in ${project_id} (${REGION_A})."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  else
    echo "VERIFY OK: Regional IP ${ip_name} absent in ${project_id} (${REGION_A})."
  fi
}

verify_absent_global_ip() {
  local project_id="$1"
  local ip_name="$2"
  local found
  found="$(gcloud compute addresses list \
    --project="${project_id}" \
    --global \
    --filter="name=${ip_name}" \
    --format="value(name)" | head -n 1)"
  if [[ -n "${found}" ]]; then
    echo "VERIFY FAIL: Global IP ${ip_name} still exists in ${project_id}."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  else
    echo "VERIFY OK: Global IP ${ip_name} absent in ${project_id}."
  fi
}

# Delete only known dry-run dataset resources.
delete_vm_if_exists "${TARGET_PROJECT_A}" "${VM_1}"
delete_vm_if_exists "${TARGET_PROJECT_B}" "${VM_2}"

delete_disk_if_exists "${TARGET_PROJECT_A}" "${DISK_1}"
delete_disk_if_exists "${TARGET_PROJECT_B}" "${DISK_2}"

delete_regional_ip_if_exists "${TARGET_PROJECT_A}" "${IP_REG_1}"
delete_global_ip_if_exists "${TARGET_PROJECT_B}" "${IP_GLB_1}"

echo
echo "=== Cleanup Verification ==="
verify_absent_instance "${TARGET_PROJECT_A}" "${VM_1}"
verify_absent_instance "${TARGET_PROJECT_B}" "${VM_2}"
verify_absent_disk "${TARGET_PROJECT_A}" "${DISK_1}"
verify_absent_disk "${TARGET_PROJECT_B}" "${DISK_2}"
verify_absent_regional_ip "${TARGET_PROJECT_A}" "${IP_REG_1}"
verify_absent_global_ip "${TARGET_PROJECT_B}" "${IP_GLB_1}"

echo
echo "=== Dry-run Dataset Cleanup: Summary ==="
echo "Deleted resources: ${DELETED_COUNT}"
echo "Already missing:   ${MISSING_COUNT}"
echo "Failures:          ${FAILED_COUNT}"

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  echo "Cleanup completed with failures. Review messages above."
  exit 1
fi

echo "Cleanup completed successfully."
