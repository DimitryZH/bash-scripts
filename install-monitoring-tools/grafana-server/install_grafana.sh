#!/bin/bash
#--------------------------------------------------------------------
# Script to install Grafana Server on Linux Ubuntu 22.04
# https://grafana.com/grafana/download
#--------------------------------------------------------------------
GRAFANA_VERSION="10.4.2"
PROMETHEUS_URL="http://172.31.30.156:9090"

# Update and install necessary dependencies
apt-get install -y apt-transport-https software-properties-common wget

# Create directory for storing Grafana GPG key
mkdir -p /etc/apt/keyrings/

# Download and add Grafana GPG key
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Add Grafana repository to APT sources
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# Update APT package list
apt-get update

# Install additional required packages
apt-get install -y adduser libfontconfig1 musl

# Download and install Grafana
wget https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb
dpkg -i grafana_${GRAFANA_VERSION}_amd64.deb

# Add Grafana to the system PATH
echo "export PATH=/usr/share/grafana/bin:$PATH" >> /etc/profile

# Configure Prometheus as a data source for Grafana
cat <<EOF> /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: ${PROMETHEUS_URL}
EOF

# Reload systemd to recognize Grafana service
systemctl daemon-reload

# Enable Grafana service to start on boot
systemctl enable grafana-server

# Start Grafana service
systemctl start grafana-server

# Check the status of Grafana service
systemctl status grafana-server
