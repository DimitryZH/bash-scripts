
#!/bin/bash
#--------------------------------------------------------------------
# Script to Install Prometheus Server on Linux Ubuntu (22.04)
#--------------------------------------------------------------------

# Define Prometheus version and directory paths
PROMETHEUS_VERSION="2.51.1"
PROMETHEUS_FOLDER_CONFIG="/etc/prometheus"
PROMETHEUS_FOLDER_TSDATA="/etc/prometheus/data"

# Download Prometheus release from GitHub
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar xvfz prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
cd prometheus-$PROMETHEUS_VERSION.linux-amd64

# Install Prometheus binary
mv prometheus /usr/bin/
rm -rf /tmp/prometheus*

# Create directories for Prometheus configuration and time-series data storage
mkdir -p $PROMETHEUS_FOLDER_CONFIG
mkdir -p $PROMETHEUS_FOLDER_TSDATA

# Generate Prometheus configuration file
cat <<EOF> $PROMETHEUS_FOLDER_CONFIG/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name      : "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
EOF

# Create system user for Prometheus and set permissions
useradd -rs /bin/false prometheus
chown prometheus:prometheus /usr/bin/prometheus
chown prometheus:prometheus $PROMETHEUS_FOLDER_CONFIG
chown prometheus:prometheus $PROMETHEUS_FOLDER_CONFIG/prometheus.yml
chown prometheus:prometheus $PROMETHEUS_FOLDER_TSDATA

# Create systemd service unit file for Prometheus
cat <<EOF> /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
ExecStart=/usr/bin/prometheus \
  --config.file       ${PROMETHEUS_FOLDER_CONFIG}/prometheus.yml \
  --storage.tsdb.path ${PROMETHEUS_FOLDER_TSDATA}

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to load the new service unit, start Prometheus service, and enable auto-start at boot
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus
systemctl status prometheus --no-pager

# Display installed Prometheus version
prometheus --version
