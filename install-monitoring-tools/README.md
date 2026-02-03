# Monitoring Tools

This directory groups together scripts and guides for setting up common monitoring stacks on Linux servers. It focuses on:

- **Prometheus + Node Exporter** for metrics collection
- **Grafana** for metrics visualization
- **Zabbix** for full-featured infrastructure monitoring

All subdirectories are self-contained examples or installers that can be used independently.

## Directory Structure

```text
install-monitoring-tools/
├── README.md
├── grafana-server/
│   ├── install_grafana.sh
│   └── README.md
├── prometheus-stack/
│   ├── install_prometheus_ubuntu.sh
│   ├── install_prometheus_node_exporter.sh
│   └── README.md
└── zabbix-server/
    └── README.md
```

## Submodules

- **Grafana Server (`grafana-server/`)**  
  Automated installation and configuration of Grafana on Ubuntu 22.04, including provisioning Prometheus as a data source and configuring Grafana as a systemd service.

- **Prometheus Stack (`prometheus-stack/`)**  
  Scripts to install Prometheus Server as a systemd service and deploy Node Exporter on a separate Ubuntu instance. The documentation shows how to wire them together using a basic `prometheus.yml` scrape configuration and provides a detailed walkthrough of the Prometheus installation process.

- **Zabbix Server (`zabbix-server/`)**  
  A step-by-step guide for installing and configuring Zabbix Server 7.0 on CentOS 8 with PostgreSQL 14 and Nginx.

## Repository Context

These monitoring components are part of the wider Bash Automation Scripts Collection. For an overview of the full repository and other automation modules, see the root [`README.md`](../README.md).

