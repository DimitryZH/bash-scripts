# Bash Automation Scripts Collection

## Overview

This repository is a curated collection of Bash scripts for common DevOps and system administration tasks, including:

- Cloud infrastructure discovery and provisioning
- Workstation / server bootstrap and tooling installation
- Monitoring and observability stack setup
- Backup automation
- User lifecycle management on Linux servers

Each subdirectory is self-contained and includes its own `README.md` with usage details.

## Repository Structure

```text
.
├── README.md
├── aws-resource-tracker/
│   ├── resource_tracker.sh
│   ├── resourceTracker
│   └── README.md
├── bash-backup-automation/
│   ├── backup_script.sh
│   ├── LICENSE
│   └── README.md
├── gcp-startup-script/
│   ├── startup.sh
│   └── README.md
├── install-monitoring-tools/
│   ├── README.md
│   ├── grafana-server/
│   │   ├── install_grafana.sh
│   │   └── README.md
│   ├── prometheus-stack/
│   │   ├── install_prometheus_ubuntu.sh
│   │   ├── install_prometheus_node_exporter.sh
│   │   └── README.md
│   └── zabbix-server/
│       └── README.md
├── install-ubuntu-packages/
│   ├── install_ubuntu_packages.sh
│   └── README.md
└── user-management-script/
    ├── create_user_ssh_pub.sh
    ├── LICENSE
    └── README.md
```

## Modules

| Module | Path | Docs | Description |
| ------ | ---- | ---- | ----------- |
| AWS Resource Tracker | `aws-resource-tracker/` | [README](aws-resource-tracker/README.md) | Discover and report on AWS resources across multiple services. |
| Backup Automation | `bash-backup-automation/` | [README](bash-backup-automation/README.md) | Automated filesystem backups with logging, compression, and error handling. |
| GCP Startup Script | `gcp-startup-script/` | [README](gcp-startup-script/README.md) | Startup script for provisioning a GCP Compute Engine VM for a Flask app. |
| Ubuntu Tools Installer | `install-ubuntu-packages/` | [README](install-ubuntu-packages/README.md) | One-shot installer for common Dev, DevOps, and security tooling on Ubuntu 22.04. |
| Monitoring Tools | `install-monitoring-tools/` | [README](install-monitoring-tools/README.md) | Scripts and guides for Prometheus, Node Exporter, Grafana, and Zabbix. |
| User Management Script | `user-management-script/` | [README](user-management-script/README.md) | Interactive user creation and SSH key provisioning for Linux hosts. |

For detailed usage, refer to the `README.md` in each module directory.

## Monitoring Stack Modules

The `install-monitoring-tools/` directory groups several related monitoring components:

- `grafana-server/` – Install and configure Grafana Server on Ubuntu, including Prometheus as a data source.
- `prometheus-stack/` – Install Prometheus as a service, deploy Node Exporter, and configure a basic scrape configuration between them.
- `zabbix-server/` – Step-by-step guide to running a Zabbix monitoring server with PostgreSQL on CentOS 8.

See [`install-monitoring-tools/README.md`](install-monitoring-tools/README.md) for details.

## Getting Started

Clone the repository:

```bash
git clone https://github.com/your-username/bash-scripts.git
cd bash-scripts
```

Navigate to the directory of the script you want to use and follow the instructions in that module's `README.md`.

### Common Pattern for Running Scripts

Most scripts follow this general pattern:

```bash
chmod +x ./script_name.sh
sudo ./script_name.sh          # when root privileges are required
./script_name.sh [arguments]   # when no elevation is needed
```

Refer to each module’s documentation for script-specific arguments and prerequisites.

## Prerequisites

Depending on the module you use, you may need some of the following:

- **Bash** (on a Unix-like system such as Ubuntu or CentOS)
- **Root or sudo access** (for system-level install and configuration scripts)
- **AWS CLI** – for `aws-resource-tracker`
- **Google Cloud SDK** – for `gcp-startup-script`
- **Docker / kubectl / Helm / etc.** – installed by `install-ubuntu-packages`
- Internet access from the target machine to download packages and container images

Each module’s `README.md` lists its own detailed prerequisites.


## Contributing

Contributions are welcome. To add a new script or improve an existing one:

1. Fork the repository.
2. Create a feature branch, for example:
   ```bash
   git checkout -b feature/new-script
   ```
3. Place your script in a dedicated subdirectory with its own `README.md`.
4. Update this root `README.md` to include your module.
5. Open a Pull Request with a clear description of the change.


