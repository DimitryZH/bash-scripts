# Ubuntu Tools Installer

## Overview

This project provides an automated Bash script for setting up a comprehensive development and CI/CD environment on Ubuntu 22.04. The script, `install_ubuntu_packages.sh`, installs essential tools and applications including Java, Jenkins, Git, Docker, Kubectl, Helm, AWS CLI, eksctl, Terraform, and Trivy. By executing this script, users can quickly configure a robust and ready-to-use environment for various development and deployment tasks.
I created this script for recovery purposes to quickly restore my workstation setup. These tools are simple to install even in the most difficult cases. For more specific installation scripts, you can check my other repositories:
- [Installing Prometheus Server on Linux Ubuntu 22.04 as a Service](https://github.com/DimitryZH/installing-prometheus-server/blob/main/install_prometheus_ubuntu.sh)
- [Installing Prometheus Node Exporter](https://github.com/DimitryZH/prometheus-monitoring/blob/main/install_prometheus_node_exporter.sh)

## Features

- **Java Installation**: Installs OpenJDK 17 (JRE and JDK).
- **Jenkins Setup**: Adds Jenkins repository and installs Jenkins for CI/CD.
- **Git Installation**: Installs Git for version control.
- **Docker Setup**: Installs Docker, adds necessary user permissions, and configures the Docker daemon.
- **Kubectl Installation**: Installs Kubectl for managing Kubernetes clusters.
- **Helm Installation**: Installs Helm via Snap for Kubernetes package management.
- **AWS CLI Installation**: Installs the AWS CLI v2 for managing AWS services.
- **eksctl Installation**: Installs eksctl for managing EKS clusters.
- **Terraform Installation**: Adds the HashiCorp repository and installs Terraform.
- **Trivy Installation**: Adds the Trivy repository and installs Trivy for container security scanning.

## Usage

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/DimitryZH/install-ubuntu-packages.git
   ```
2. **Run the Script:**
   ```bash
   chmod +x install_ubuntu_packages.sh
   sudo ./install_ubuntu_packages.sh
   ```
3. **Ensure your user is added to the Docker group**:
   ```bash
   sudo usermod -aG docker $USER
   ```
4. **Verify the installation of each tool by running their respective version commands, e.g.**:
```bash
java --version
jenkins --version
git --version
docker --version
kubectl version --client
helm version
aws --version
eksctl version
terraform version
trivy --version
```
