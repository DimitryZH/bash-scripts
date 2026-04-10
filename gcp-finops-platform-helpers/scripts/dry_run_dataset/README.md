# Dry Run Dataset Helper Scripts

This directory contains helper scripts for creating and cleaning a deterministic GCP dataset used in FinOps dry-run validation.

## Files

- `gcloud_commands.sh`: Creates baseline test resources with fixed names.
- `cleanup_gcloud_commands.sh`: Deletes only those known baseline resources and verifies they are gone.

## Dataset Shape

The creation script provisions:

- 2 Compute Engine VM instances, then stops them.
- 2 unattached persistent disks.
- 1 unused regional static IP.
- 1 unused global static IP.

## Prerequisites

1. Install and initialize Google Cloud CLI (`gcloud`).
2. Authenticate:
   - `gcloud auth login`
   - `gcloud auth application-default login` (if your workflow requires ADC)
3. Ensure permissions to create and delete Compute resources.
4. Ensure required APIs are enabled (for example `compute.googleapis.com`).

## Safe Execution

Run from the module root:

```bash
chmod +x scripts/dry_run_dataset/gcloud_commands.sh
TARGET_PROJECT_A="your-target-project-a" \
TARGET_PROJECT_B="your-target-project-b" \
./scripts/dry_run_dataset/gcloud_commands.sh
```

Safety notes:

- Resource names are deterministic and reused across runs.
- If resources already exist, creation commands may fail.
- Validate current project state before re-running.

## Cleanup

Run from the module root:

```bash
chmod +x scripts/dry_run_dataset/cleanup_gcloud_commands.sh
TARGET_PROJECT_A="your-target-project-a" \
TARGET_PROJECT_B="your-target-project-b" \
./scripts/dry_run_dataset/cleanup_gcloud_commands.sh
```

Cleanup notes:

- Deletes only known resources created by `gcloud_commands.sh`.
- Performs verification after delete operations.
- Exits with status `1` if verification finds remaining resources.

## Manual Verification Commands

Check stopped VMs:

```bash
gcloud compute instances list --project="your-target-project-a" \
  --filter="name=finops-dr-vm-stopped-01" \
  --format="table(name,status,zone)"
gcloud compute instances list --project="your-target-project-b" \
  --filter="name=finops-dr-vm-stopped-02" \
  --format="table(name,status,zone)"
```

Check unattached disks:

```bash
gcloud compute disks list --project="your-target-project-a" \
  --filter="name=finops-dr-disk-unattached-01" \
  --format="table(name,sizeGb,type,zone,users)"
gcloud compute disks list --project="your-target-project-b" \
  --filter="name=finops-dr-disk-unattached-02" \
  --format="table(name,sizeGb,type,zone,users)"
```

Check static IPs:

```bash
gcloud compute addresses list --project="your-target-project-a" \
  --filter="name=finops-dr-ip-unused-reg-01" \
  --format="table(name,addressType,region,status,users)"
gcloud compute addresses list --project="your-target-project-b" \
  --filter="name=finops-dr-ip-unused-glb-01" \
  --format="table(name,addressType,status,users)"
```
