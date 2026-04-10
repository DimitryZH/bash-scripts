#!/usr/bin/env bash
set -euo pipefail

# Dry-run dataset creation script for FinOps validation.
# This script creates a deterministic, read-only-validation dataset:
# - 2 VM instances, then stops them
# - 2 unattached disks
# - 2 reserved static external IPs (1 regional, 1 global)
#
# IMPORTANT:
# - Replace project IDs below before running.
# - This script intentionally does NOT include cleanup/delete commands.
# - Re-running without cleanup may fail on existing resource names.

TARGET_PROJECT_A="${TARGET_PROJECT_A:-REPLACE_WITH_TARGET_PROJECT_A}"
TARGET_PROJECT_B="${TARGET_PROJECT_B:-REPLACE_WITH_TARGET_PROJECT_B}"

ZONE_A="us-central1-a"
ZONE_A_FALLBACK_1="us-central1-b"
ZONE_A_FALLBACK_2="us-central1-c"
REGION_A="us-central1"
ZONE_B="us-east1-b"
ZONE_B_FALLBACK_1="us-east1-c"
ZONE_B_FALLBACK_2="us-east1-d"
REGION_B="us-east1"

VM_1="finops-dr-vm-stopped-01"
VM_2="finops-dr-vm-stopped-02"

DISK_1="finops-dr-disk-unattached-01"
DISK_2="finops-dr-disk-unattached-02"

IP_REG_1="finops-dr-ip-unused-reg-01"
IP_GLB_1="finops-dr-ip-unused-glb-01"

create_vm_with_fallback() {
  local vm_name="$1"
  local target_project="$2"
  local machine_primary="$3"
  local machine_fallback="$4"
  local boot_disk_size="$5"
  local zone_primary="$6"
  local zone_fallback_1="$7"
  local zone_fallback_2="$8"

  local chosen_zone=""
  local chosen_machine=""

  echo "Creating VM ${vm_name} in ${target_project} (${zone_primary})..."
  if gcloud compute instances create "${vm_name}" \
    --project="${target_project}" \
    --zone="${zone_primary}" \
    --machine-type="${machine_primary}" \
    --boot-disk-size="${boot_disk_size}" \
    --boot-disk-type="pd-balanced" \
    --image-family="debian-12" \
    --image-project="debian-cloud"; then
    chosen_zone="${zone_primary}"
    chosen_machine="${machine_primary}"
  else
    echo "Primary zone failed, retrying in ${zone_fallback_1}..."
    if gcloud compute instances create "${vm_name}" \
      --project="${target_project}" \
      --zone="${zone_fallback_1}" \
      --machine-type="${machine_primary}" \
      --boot-disk-size="${boot_disk_size}" \
      --boot-disk-type="pd-balanced" \
      --image-family="debian-12" \
      --image-project="debian-cloud"; then
      chosen_zone="${zone_fallback_1}"
      chosen_machine="${machine_primary}"
    else
      if [[ "${machine_fallback}" != "${machine_primary}" ]]; then
        echo "Primary machine type failed in fallback zones, retrying in ${zone_fallback_2} with ${machine_fallback}..."
      else
        echo "Secondary zone failed, retrying in ${zone_fallback_2}..."
      fi

      if gcloud compute instances create "${vm_name}" \
        --project="${target_project}" \
        --zone="${zone_fallback_2}" \
        --machine-type="${machine_fallback}" \
        --boot-disk-size="${boot_disk_size}" \
        --boot-disk-type="pd-balanced" \
        --image-family="debian-12" \
        --image-project="debian-cloud"; then
        chosen_zone="${zone_fallback_2}"
        chosen_machine="${machine_fallback}"
      else
        echo "WARNING: VM ${vm_name} creation failed after fallback attempts. Deferring compute coverage for this run."
        return 1
      fi
    fi
  fi

  CREATED_VM_ZONE="${chosen_zone}"
  CREATED_VM_MACHINE="${chosen_machine}"
}

if [[ "$TARGET_PROJECT_A" == REPLACE_WITH_TARGET_PROJECT_A || "$TARGET_PROJECT_B" == REPLACE_WITH_TARGET_PROJECT_B ]]; then
  echo "Set TARGET_PROJECT_A and TARGET_PROJECT_B environment variables (or edit this script) before running."
  exit 1
fi

VM_1_CREATED="no"
VM_2_CREATED="no"

if create_vm_with_fallback \
  "${VM_1}" \
  "${TARGET_PROJECT_A}" \
  "e2-medium" \
  "e2-small" \
  "30GB" \
  "${ZONE_A}" \
  "${ZONE_A_FALLBACK_1}" \
  "${ZONE_A_FALLBACK_2}"; then
  VM_1_ZONE_USED="${CREATED_VM_ZONE}"
  VM_1_MACHINE_USED="${CREATED_VM_MACHINE}"
  VM_1_CREATED="yes"
  echo "VM ${VM_1} created in ${VM_1_ZONE_USED} with ${VM_1_MACHINE_USED}."

  echo "Stopping VM ${VM_1} to enforce TERMINATED state..."
  gcloud compute instances stop "${VM_1}" \
    --project="${TARGET_PROJECT_A}" \
    --zone="${VM_1_ZONE_USED}"
else
  echo "WARNING: Skipping VM stop for ${VM_1} because creation did not succeed."
fi

if create_vm_with_fallback \
  "${VM_2}" \
  "${TARGET_PROJECT_B}" \
  "e2-standard-2" \
  "e2-standard-2" \
  "50GB" \
  "${ZONE_B}" \
  "${ZONE_B_FALLBACK_1}" \
  "${ZONE_B_FALLBACK_2}"; then
  VM_2_ZONE_USED="${CREATED_VM_ZONE}"
  VM_2_MACHINE_USED="${CREATED_VM_MACHINE}"
  VM_2_CREATED="yes"
  echo "VM ${VM_2} created in ${VM_2_ZONE_USED} with ${VM_2_MACHINE_USED}."

  echo "Stopping VM ${VM_2} to enforce TERMINATED state..."
  gcloud compute instances stop "${VM_2}" \
    --project="${TARGET_PROJECT_B}" \
    --zone="${VM_2_ZONE_USED}"
else
  echo "WARNING: Skipping VM stop for ${VM_2} because creation did not succeed."
fi

echo "Creating unattached disk ${DISK_1} in ${TARGET_PROJECT_A} (${ZONE_A})..."
gcloud compute disks create "${DISK_1}" \
  --project="${TARGET_PROJECT_A}" \
  --zone="${ZONE_A}" \
  --type="pd-standard" \
  --size="50GB"

echo "Creating unattached disk ${DISK_2} in ${TARGET_PROJECT_B} (${ZONE_B})..."
gcloud compute disks create "${DISK_2}" \
  --project="${TARGET_PROJECT_B}" \
  --zone="${ZONE_B}" \
  --type="pd-ssd" \
  --size="100GB"

echo "Reserving unused regional static IP ${IP_REG_1} in ${TARGET_PROJECT_A} (${REGION_A})..."
gcloud compute addresses create "${IP_REG_1}" \
  --project="${TARGET_PROJECT_A}" \
  --region="${REGION_A}"

echo "Reserving unused global static IP ${IP_GLB_1} in ${TARGET_PROJECT_B}..."
gcloud compute addresses create "${IP_GLB_1}" \
  --project="${TARGET_PROJECT_B}" \
  --global

echo "Dry-run dataset creation complete."
if [[ "${VM_1_CREATED}" == "no" || "${VM_2_CREATED}" == "no" ]]; then
  echo "NOTE: Compute coverage is partial for this run due VM capacity constraints."
fi
echo "Next: manually verify states before running the FinOps assessment."
