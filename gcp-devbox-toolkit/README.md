# GCP DevBox Toolkit

Reusable Bash utilities for creating, accessing, validating, and documenting a
Google Cloud development sandbox.

## What a DevBox Is

A DevBox is a dedicated Google Compute Engine VM used as an isolated remote
development and validation environment. It separates runtime work from the
local workstation and can host containerized applications, .NET workloads,
test tools, migration experiments, and AI-assisted engineering sessions.

This toolkit manages the environment around those workloads. It does not
install an AI agent or application stack by itself.

## What This Module Demonstrates

- local Google Cloud readiness validation;
- parameterized Compute Engine provisioning;
- explicit cost and creation confirmation;
- secure defaults with no external IP;
- OS Login and optional service-account removal;
- SSH access through Identity-Aware Proxy;
- in-VM resource and tool validation;
- timestamped operational evidence collection;
- configuration reuse without executing config files as shell code.

## Origin

This module was generalized from the Google Cloud DevBox workflow in the
[`application-modernization-lab`](https://github.com/DimitryZH/application-modernization-lab/tree/main/experiments/04-google-cloud-devbox)
project. The original experiment validated remote development and
Compose-to-Aspire migration workflows. This version removes experiment-specific
project IDs, VM names, labels, paths, and application assumptions.

## Repository Structure

```text
gcp-devbox-toolkit/
├── README.md
├── config/
│   └── example.env
├── docs/
│   ├── architecture.md
│   └── security-model.md
└── scripts/
    ├── check_local_gcloud.sh
    ├── create_gce_devbox.sh
    ├── connect_gce_devbox.sh
    ├── check_devbox_prerequisites.sh
    └── collect_devbox_evidence.sh
```

## Lifecycle

```text
Local workstation
  |
  | check_local_gcloud.sh
  v
Google Cloud readiness
  |
  | create_gce_devbox.sh
  v
Compute Engine DevBox
  |
  | connect_gce_devbox.sh through IAP
  v
Remote Linux session
  |
  | check_devbox_prerequisites.sh
  v
Validated development environment
  |
  | collect_devbox_evidence.sh
  v
Timestamped evidence artifact
```

## Scripts

### `check_local_gcloud.sh`

Performs read-only checks for:

- Google Cloud CLI availability;
- active authenticated identity;
- target project access;
- active project alignment;
- required Compute Engine, IAP, Service Usage, and Resource Manager APIs.

It does not enable APIs or create resources.

### `create_gce_devbox.sh`

Creates a parameterized Compute Engine VM after validating:

- project access;
- VM name availability;
- network and subnet existence;
- required IAP firewall rule;
- public SSH deny rule when an external IP is requested.

Safety controls include:

- no external IP by default;
- `--dry-run`;
- explicit confirmation before a billable resource is created;
- refusal to replace an existing VM;
- Shielded VM features;
- OS Login;
- optional removal of the VM service account and OAuth scopes.

The script deliberately does not create firewall rules, networks, subnets,
service accounts, or APIs.

### `connect_gce_devbox.sh`

Connects with `gcloud compute ssh` and uses IAP tunneling by default.

Arguments after `--` are forwarded to the underlying SSH invocation:

```bash
./scripts/connect_gce_devbox.sh \
  --config config/local.env \
  -- -L 8080:127.0.0.1:8080
```

### `check_devbox_prerequisites.sh`

Runs inside the VM and validates:

- operating system visibility;
- CPU, memory, and free disk thresholds;
- non-root execution;
- configured development tools;
- Docker Compose availability;
- access to the Docker daemon;
- optional Chrome or Chromium availability.

### `collect_devbox_evidence.sh`

Creates a timestamped Markdown report containing:

- OS and kernel information;
- compute resources;
- tool versions;
- optional Docker details;
- optional Git repository state;
- optional tails of validation logs.

Evidence can reveal project paths, repository state, container names, host
metadata, and log content. Review it before publication.

## Configuration

Copy the example file to a local untracked path:

```bash
cp config/example.env config/local.env
```

Replace `REPLACE_WITH_GCP_PROJECT_ID` and adjust the remaining values.

The same configuration file can be used by all scripts. Each script reads only
approved keys and does not source or execute the file.

Configuration precedence:

1. command-line arguments;
2. values from `--config`;
3. existing environment variables;
4. built-in defaults.

## Quick Start

Validate the workstation:

```bash
./scripts/check_local_gcloud.sh \
  --config config/local.env
```

Preview VM creation:

```bash
./scripts/create_gce_devbox.sh \
  --config config/local.env \
  --dry-run
```

Create the VM:

```bash
./scripts/create_gce_devbox.sh \
  --config config/local.env
```

Connect through IAP:

```bash
./scripts/connect_gce_devbox.sh \
  --config config/local.env
```

Inside the VM:

```bash
./scripts/check_devbox_prerequisites.sh \
  --config config/local.env
```

Collect evidence:

```bash
./scripts/collect_devbox_evidence.sh \
  --config config/local.env
```

## External IP and Outbound Access

The default configuration creates a VM without an external IP.

A private VM still needs an approved outbound path when package downloads,
container pulls, or external APIs are required. Common options include Cloud
NAT, a controlled proxy, or Private Google Access for supported Google APIs.

When `CREATE_EXTERNAL_IP=true`, the toolkit can require a pre-existing firewall
rule that denies public SSH. Administrative access should still use IAP.

## Prerequisites

Local workstation:

- Bash 4 or later;
- authenticated Google Cloud CLI;
- permissions to inspect the project and create Compute Engine instances;
- IAP access permissions when tunneling is enabled.

DevBox VM:

- a supported Linux distribution;
- tools appropriate for the intended workloads;
- Docker daemon access for container validation.

## Exit Codes

| Code | Meaning |
| ---: | --- |
| `0` | Requested operation or validation completed. |
| `1` | A runtime check or Google Cloud operation failed. |
| `2` | Invalid arguments, configuration, or missing local dependencies. |

## Scope

This is a development and validation toolkit, not a production platform. It
does not provide automatic cleanup, patch management, centralized secrets,
continuous monitoring, backup, policy enforcement, or multi-user tenancy.
