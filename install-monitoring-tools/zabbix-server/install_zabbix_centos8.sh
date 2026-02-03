#!/usr/bin/env bash

# Zabbix 7.0 + PostgreSQL 14 + Nginx installation script for CentOS 8
#
# This script automates the main steps described in the local README:
#  - Build and configure PostgreSQL 14 from source
#  - Adjust CentOS 8 repositories for EOL state
#  - Install and configure Zabbix Server 7.0 with PostgreSQL backend
#  - Configure Nginx for the Zabbix web interface
#  - Enable and start all relevant services
#
# Usage (on a CentOS 8 host):
#   sudo bash install_zabbix_centos8.sh <zabbix_db_password>
#
# Note: This script is intended for lab/demo environments and closely
#       follows the manual instructions documented in README.md.

set -euo pipefail

ZABBIX_DB_NAME="zabbix_db"
ZABBIX_DB_USER="zabbix"
ZABBIX_DB_PASSWORD="${1:-}"

POSTGRES_PREFIX="/usr/local/pgsql"
POSTGRES_DATA_DIR="$POSTGRES_PREFIX/data"

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (use sudo)." >&2
    exit 1
  fi
}

require_password() {
  if [[ -z "$ZABBIX_DB_PASSWORD" ]]; then
    echo "[USAGE] sudo bash install_zabbix_centos8.sh <zabbix_db_password>" >&2
    exit 1
  fi
}

install_postgresql_14() {
  echo "[INFO] Installing PostgreSQL 14 from source..."

  cd /usr/src || mkdir -p /usr/src && cd /usr/src

  if [[ ! -d postgresql-14.0 ]]; then
    curl -LO https://ftp.postgresql.org/pub/source/v14.0/postgresql-14.0.tar.gz
    tar xvzf postgresql-14.0.tar.gz
  fi

  cd postgresql-14.0
  ./configure --without-readline
  make
  make install

  # Create postgres user and data directory
  if ! id postgres >/dev/null 2>&1; then
    adduser postgres
  fi

  mkdir -p "$POSTGRES_DATA_DIR"
  chown postgres:postgres "$POSTGRES_DATA_DIR"

  sudo -u postgres bash -c "
    if [[ ! -f '$POSTGRES_DATA_DIR/PG_VERSION' ]]; then
      $POSTGRES_PREFIX/bin/initdb -D '$POSTGRES_DATA_DIR'
    fi
    $POSTGRES_PREFIX/bin/pg_ctl -D '$POSTGRES_DATA_DIR' -l '$POSTGRES_DATA_DIR/logfile' start
  "

  echo "[INFO] PostgreSQL 14 installed and started."
}

create_zabbix_database() {
  echo "[INFO] Creating Zabbix database and user..."

  sudo -u postgres "$POSTGRES_PREFIX/bin/psql" -v ON_ERROR_STOP=1 <<SQL
DO

\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$ZABBIX_DB_USER') THEN
      CREATE ROLE $ZABBIX_DB_USER LOGIN PASSWORD '$ZABBIX_DB_PASSWORD';
   END IF;
END
\$do\$;

CREATE DATABASE $ZABBIX_DB_NAME OWNER $ZABBIX_DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $ZABBIX_DB_NAME TO $ZABBIX_DB_USER;
SQL

  echo "[INFO] Zabbix database '$ZABBIX_DB_NAME' and user '$ZABBIX_DB_USER' configured."
}

fix_centos8_repos() {
  echo "[INFO] Updating CentOS 8 repositories for EOL vault..."

  sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* || true
  sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* || true

  yum clean all
  yum -y update

  echo "[INFO] CentOS 8 repositories now point to vault.centos.org."
}

install_zabbix_packages() {
  echo "[INFO] Installing Zabbix packages..."

  rpm -Uvh https://repo.zabbix.com/zabbix/7.0/centos/8/x86_64/zabbix-release-7.0-1.el8.noarch.rpm
  dnf clean all
  dnf -y module switch-to php:8.0

  dnf -y install \
    zabbix-server-pgsql \
    zabbix-web-pgsql \
    zabbix-nginx-conf \
    zabbix-sql-scripts \
    zabbix-selinux-policy \
    zabbix-agent

  echo "[INFO] Zabbix server, web, agent, and dependencies installed."
}

import_zabbix_schema() {
  echo "[INFO] Importing Zabbix database schema..."

  zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | \
    "$POSTGRES_PREFIX/bin/psql" -U "$ZABBIX_DB_USER" "$ZABBIX_DB_NAME"

  echo "[INFO] Zabbix schema imported into database '$ZABBIX_DB_NAME'."
}

configure_zabbix_server_conf() {
  echo "[INFO] Configuring /etc/zabbix/zabbix-server.conf..."

  local conf="/etc/zabbix/zabbix-server.conf"

  sed -i "s/^#\?DBName=.*/DBName=$ZABBIX_DB_NAME/" "$conf"
  sed -i "s/^#\?DBUser=.*/DBUser=$ZABBIX_DB_USER/" "$conf"

  if grep -q '^#\?DBPassword=' "$conf"; then
    sed -i "s/^#\?DBPassword=.*/DBPassword=$ZABBIX_DB_PASSWORD/" "$conf"
  else
    echo "DBPassword=$ZABBIX_DB_PASSWORD" >>"$conf"
  fi

  echo "[INFO] Zabbix server configuration updated with database settings."
}

configure_nginx_for_zabbix() {
  echo "[INFO] Configuring Nginx for Zabbix frontend..."

  local conf="/etc/nginx/conf.d/zabbix.conf"
  if [[ -f "$conf" ]]; then
    sed -i 's/^#\?\s*listen .*/listen 8080;/' "$conf"
    sed -i 's/^#\?\s*server_name .*/server_name example.com;/' "$conf"
  fi

  echo "[INFO] Nginx configuration for Zabbix updated (listen 8080, server_name example.com)."
}

enable_and_start_services() {
  echo "[INFO] Enabling and starting Zabbix and web stack services..."

  systemctl restart zabbix-server zabbix-agent nginx php-fpm
  systemctl enable zabbix-server zabbix-agent nginx php-fpm

  echo "[INFO] Services restarted and enabled on boot."
}

print_summary() {
  cat <<EOF

[SUMMARY]
Zabbix 7.0 with PostgreSQL 14 and Nginx has been installed and configured.

- PostgreSQL data dir: $POSTGRES_DATA_DIR
- Zabbix DB name:      $ZABBIX_DB_NAME
- Zabbix DB user:      $ZABBIX_DB_USER

You can access the Zabbix web UI at:

  http://your_IP:8080/

Follow the on-screen installer to complete the initial frontend configuration.

For more details, see the local README in this directory.
EOF
}

main() {
  require_root
  require_password

  install_postgresql_14
  create_zabbix_database
  fix_centos8_repos
  install_zabbix_packages
  import_zabbix_schema
  configure_zabbix_server_conf
  configure_nginx_for_zabbix
  enable_and_start_services
  print_summary
}

main "$@"

