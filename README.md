# Bash DevOps Automation Toolkit

A curated collection of reusable Bash modules for cloud infrastructure, secure cloud operations, AI-agent runtime diagnostics, FinOps validation, observability, and Linux administration.

## Overview

This repository brings together self-contained Bash automation modules for practical DevOps, cloud, platform engineering, SRE, and Linux administration workflows.

The collection includes securedevelopment environments, AI Agents operational diagnostics, FinOps validation helpers, infrastructure discovery, observability tooling, system bootstrap automation, backup workflows, and Linux management.

Each module is maintained in its own directory and includes dedicated documentation covering its purpose, prerequisites, configuration, safety boundaries, and usage.

## Engineering Principles

- Self-contained modules with dedicated documentation
- Parameterized configuration instead of hard-coded environments
- Read-only validation and dry-run modes where practical
- Explicit confirmation before billable or mutating operations
- No credentials, private keys, or secrets stored in the repository
- Clear prerequisites, safety boundaries, and exit behavior
- Reusable tooling generalized from real cloud and platform engineering work

## Featured Modules

| Module | Focus | Key Capabilities |
| --- | --- | --- |
| [GCP DevBox Toolkit](gcp-devbox-toolkit/README.md) | Secure remote development and validation environment on Google Cloud | Local GCP readiness checks, parameterized GCE provisioning, IAP-based SSH access, in-VM prerequisite validation, and timestamped evidence collection |
| [OpenClaw Runtime Preflight](openclaw-runtime-preflight/README.md) | Operational validation for a containerized OpenClaw runtime | systemd and container checks, persistent storage validation, health and readiness probes, authenticated API validation, and control-plane inspection |
| [DevClaw Operations Toolkit](devclaw-operations-toolkit/README.md) | Diagnostics for DevClaw multi-agent orchestration running with OpenClaw | Circuit-breaker investigation, resilience implementation inspection, state analysis, bounded file inventory, and optional runtime task-status probing |
| [GCP FinOps Platform Helpers](gcp-finops-platform-helpers/README.md) | Repeatable Google Cloud FinOps validation workflows | Controlled dry-run execution, deterministic GCP test datasets, targeted cleanup, and post-cleanup verification |

## Additional Modules

| Module | Focus | Key Capabilities |
| --- | --- | --- |
| [Monitoring Tools](install-monitoring-tools/README.md) | Linux observability stack installation | Prometheus, Node Exporter, Grafana, and Zabbix setup guides and automation |
| [AWS Resource Tracker](aws-resource-tracker/README.md) | AWS infrastructure discovery and reporting | Resource inventory across services including EC2, S3, Lambda, IAM, DynamoDB, Route 53, Amplify, and EKS |
| [Ubuntu Tools Installer](install-ubuntu-packages/README.md) | Development and operations workstation bootstrap | One-shot installation of common DevOps, cloud, container, and security tooling on Ubuntu |
| [Backup Automation](bash-backup-automation/README.md) | Filesystem backup workflows | Logging, archive creation, retention-oriented automation, and repeatable backup execution |
| [GCP Startup Script](gcp-startup-script/README.md) | Compute Engine application bootstrap | Startup automation for provisioning a Google Cloud VM for a Flask application |
| [User Management Script](user-management-script/README.md) | Linux account and SSH provisioning | Interactive user creation and SSH public-key configuration |

## Start Here

Start with the [GCP DevBox Toolkit](gcp-devbox-toolkit/README.md), the most complete end-to-end module in this repository.

It demonstrates a full operational workflow:

```text
Local Google Cloud readiness
        ↓
Secure Compute Engine provisioning
        ↓
IAP-based SSH access
        ↓
In-VM environment validation
        ↓
Timestamped evidence collection
```

The module is designed for isolated remote development, containerized workloads, testing, migration experiments, and AI-assisted engineering sessions.

## Getting Started

Clone the repository:

```bash
git clone https://github.com/DimitryZH/bash-scripts.git
cd bash-scripts
```

Open the README for the module you want to use:

```bash
cd gcp-devbox-toolkit
less README.md
```

Most executable scripts follow this general pattern:

```bash
chmod +x ./scripts/script_name.sh
./scripts/script_name.sh --help
```

Some modules also support configuration files, dry-run modes, or explicitly enabled deep validation:

```bash
./scripts/script_name.sh --config config/local.env
./scripts/script_name.sh --dry-run
```

Always review the module README before execution. Some operations require cloud permissions, elevated Linux privileges, access to local runtime state, or explicit confirmation before resources are changed or created.

## General Prerequisites

Requirements vary by module, but may include:

- Bash 4 or later on Linux or another Unix-like environment
- Google Cloud CLI or AWS CLI for cloud-specific modules
- Docker, systemd, `curl`, `jq`, Git, or .NET for selected workflows
- Root or `sudo` access for system-level installation and administration
- Appropriate Google Cloud or AWS IAM permissions
- Network access for package downloads, container image pulls, and cloud APIs

Each module README defines its exact prerequisites, required permissions, configuration model, safety considerations, and expected output.

## Contributing

Contributions and improvements are welcome.

To add or update a module:

1. Create a focused branch:

   ```bash
   git checkout -b feature/module-update
   ```

2. Keep the implementation in a dedicated, self-contained directory.

3. Include a module-level `README.md` describing:

   - purpose and scope;
   - prerequisites;
   - configuration;
   - usage;
   - safety boundaries;
   - expected output or exit behavior.

4. Avoid committing secrets, credentials, private keys, environment-specific tokens, or sensitive operational evidence.

5. Update this root README when adding a new module.

6. Open a pull request with a clear description of the changes and validation performed.
