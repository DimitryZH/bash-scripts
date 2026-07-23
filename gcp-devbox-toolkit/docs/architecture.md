# Architecture

## Overview

The GCP DevBox Toolkit uses a local control plane and a remote execution plane.

```text
Local workstation
  |
  | Google Cloud CLI and authenticated operator identity
  v
Google Cloud control plane
  |
  | Compute Engine API
  v
DevBox VM
  |
  | Docker, .NET, test tools, repositories, and agent workloads
  v
Validation and evidence artifacts
```

## Components

| Component | Responsibility |
| --- | --- |
| Local workstation | Runs `gcloud`, validates prerequisites, creates the VM, and opens SSH sessions. |
| Google Cloud project | Hosts Compute Engine, networking, IAM, IAP, and related APIs. |
| Compute Engine VM | Provides the isolated Linux development and validation environment. |
| IAP tunnel | Provides the default administrative SSH path without direct public SSH. |
| Configuration file | Supplies reusable non-secret parameters to every script. |
| Evidence collector | Records environment state and selected validation context. |

## Lifecycle Boundaries

The toolkit covers:

1. local readiness;
2. instance creation;
3. operator connection;
4. in-VM prerequisite validation;
5. evidence collection.

It intentionally does not install workload-specific software, clone a
particular repository, run a specific AI agent, or delete infrastructure.

## Reuse Model

The VM can be stopped when idle, restarted for later work, and reused across
multiple development or validation sessions. Reuse should remain controlled:
review installed packages, repository state, credentials, and persisted data
before assigning the same DevBox to a different trust boundary.
