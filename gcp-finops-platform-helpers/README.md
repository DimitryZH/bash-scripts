# gcp-finops-platform-helpers

Portable Bash helpers for repeatable FinOps dry-run workflows on Google Cloud.

## What This Module Includes

- `scripts/run_dry_run.sh`
  - Generic dry-run execution wrapper.
  - Validates required environment variables.
  - Prints execution context and runs a caller-provided assessment command.
  - Adds a compatibility fallback from `uvicorn` to `python -m uvicorn` when possible.

- `scripts/dry_run_dataset/gcloud_commands.sh`
  - Creates a deterministic GCP dry-run dataset for FinOps validation:
  - 2 VM instances (then stopped), 2 unattached disks, 2 unused static IPs.
  - Includes fallback logic for zone and machine type availability issues.

- `scripts/dry_run_dataset/cleanup_gcloud_commands.sh`
  - Deletes only the deterministic resources created by the dataset creation script.
  - Performs post-delete verification and returns non-zero if cleanup verification fails.

- `scripts/dry_run_dataset/README.md`
  - Focused usage guide for dataset create/cleanup flows.

## Why This Module Exists

- `run_dry_run.sh` provides a generic wrapper for controlled dry-run execution.
- The dataset create/cleanup scripts support validation against known GCP resource states.

## Prerequisites

- Bash (`/usr/bin/env bash` compatible).
- Google Cloud CLI (`gcloud`) for dataset scripts.
- Authenticated and authorized GCP identity with Compute permissions.
- Access to target projects where test resources can be created and deleted.

## Basic Usage

From this module root:

```bash
chmod +x scripts/run_dry_run.sh
PROJECT_SCOPE="proj-a,proj-b" \
DRY_RUN_CMD="python -m app.main" \
./scripts/run_dry_run.sh
```

Create dataset:

```bash
chmod +x scripts/dry_run_dataset/gcloud_commands.sh
TARGET_PROJECT_A="project-a" \
TARGET_PROJECT_B="project-b" \
./scripts/dry_run_dataset/gcloud_commands.sh
```

Cleanup dataset:

```bash
chmod +x scripts/dry_run_dataset/cleanup_gcloud_commands.sh
TARGET_PROJECT_A="project-a" \
TARGET_PROJECT_B="project-b" \
./scripts/dry_run_dataset/cleanup_gcloud_commands.sh
```

## Scope

This module is intentionally small and focused on shell utilities:

- dry-run command orchestration
- deterministic GCP test dataset creation
- deterministic GCP test dataset cleanup and verification
