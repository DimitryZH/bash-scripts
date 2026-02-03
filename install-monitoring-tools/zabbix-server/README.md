# Zabbix Monitoring Server Setup on CentOS 8

## Overview

This project demonstrates how to set up a Zabbix monitoring server on a CentOS 8 system, including the installation and configuration of PostgreSQL 14, necessary adjustments for CentOS 8 EOL, and Zabbix Server 7.0. This guide walks you through the necessary steps to get a fully functional Zabbix server.

You can either:

- Use the **automation script** in this directory for a one-shot installation, or
- Follow the **manual steps** below for a step-by-step setup.

### Quick start (automated script)

From a CentOS 8 host, run:

```bash
cd install-monitoring-tools/zabbix-server
chmod +x install_zabbix_centos8.sh
sudo ./install_zabbix_centos8.sh <zabbix_db_password>
```

The [`install_zabbix_centos8.sh`](install_zabbix_centos8.sh) script will:

- Build and configure PostgreSQL 14 under `/usr/local/pgsql`.
- Create the Zabbix database and user with the password you pass as an argument.
- Update CentOS 8 repositories to point at `vault.centos.org`.
- Install Zabbix Server 7.0, web frontend, Nginx, and the Zabbix agent.
- Import the Zabbix database schema.
- Configure `/etc/zabbix/zabbix-server.conf` with the correct DB settings.
- Configure Nginx to serve Zabbix on port `8080`.
- Enable and start `zabbix-server`, `zabbix-agent`, `nginx`, and `php-fpm`.

After the script finishes, open:

```text
http://your_IP:8080/
```

and follow the web-based installer to complete the frontend setup.

The sections below document the equivalent **manual** procedure.

## Steps

### Step 1: Install PostgreSQL 14

1. Download and extract PostgreSQL 14 source code:

   ```bash
   wget https://ftp.postgresql.org/pub/source/v14.0/postgresql-14.0.tar.gz
   tar xvzf postgresql-14.0.tar.gz
   cd postgresql-14.0
   ```

2. Configure and install PostgreSQL:

   ```bash
   ./configure --without-readline
   sudo make
   sudo make install
   ```

3. Set up PostgreSQL:

   ```bash
   sudo adduser postgres
   mkdir -p /usr/local/pgsql/data
   sudo chown postgres /usr/local/pgsql/data
   sudo su - postgres
   /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data
   /usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data -l logfile start
   /usr/local/pgsql/bin/createdb test
   /usr/local/pgsql/bin/psql test
   ```

4. Verify PostgreSQL is running:

   ```bash
   ps aux | grep postgres
   ```

5. Create a database and user for Zabbix:

   ```bash
   /usr/local/pgsql/bin/psql -U postgres
   create database zabbix_db;
   create user zabbix with password 'your_password';
   grant all privileges on database zabbix_db to zabbix;
   \q
   ```

### Step 2: Update CentOS 8 Repositories (For EOL Versions)

1. Change the repository mirrors:

   ```bash
   sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
   sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
   ```

2. Clean and update repositories:

   ```bash
   yum clean all
   yum update -y
   ```

### Step 3: Install Zabbix Server

1. Install Zabbix repository:

   ```bash
   rpm -Uvh https://repo.zabbix.com/zabbix/7.0/centos/8/x86_64/zabbix-release-7.0-1.el8.noarch.rpm
   dnf clean all
   dnf module switch-to php:8.0
   ```

2. Install Zabbix packages:

   ```bash
   dnf install zabbix-server-pgsql zabbix-web-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent
   ```

3. Set up the Zabbix database schema:

   ```bash
   zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | /usr/local/pgsql/bin/psql zabbix_db
   ```

4. Configure Zabbix server:

   ```bash
   nano /etc/zabbix/zabbix-server.conf
   ```

   Set the following parameters:

   ```bash
   DBPassword=your_password
   DBUser=zabbix
   DBName=zabbix_db
   ```

5. Configure Nginx for Zabbix:

   ```bash
   nano /etc/nginx/conf.d/zabbix.conf
   ```

   Uncomment and set:

   ```bash
   listen 8080;
   server_name example.com;
   ```

### Step 4: Start and Enable Zabbix Components

1. Restart and enable services:

   ```bash
   systemctl restart zabbix-server zabbix-agent nginx php-fpm
   systemctl enable zabbix-server zabbix-agent nginx php-fpm
   ```

### Step 5: Access Zabbix UI

Open your web browser and navigate to:

```text
http://your_IP:8080/
```

Follow the on-screen instructions to complete the Zabbix setup.

## Results

**Zabbix UI Installed:**

![Zabbix UI Installed](https://github.com/DimitryZH/install-zabbix/assets/146372946/95543776-b509-4b68-9312-0609734d3088)

**Zabbix UI Configured:**

![Zabbix UI Configured](https://github.com/DimitryZH/install-zabbix/assets/146372946/442979eb-12c2-4535-9053-02dd8bd56ece)

## Conclusion

This guide provides a step-by-step approach to installing and configuring a Zabbix monitoring server on CentOS 8 with PostgreSQL 14. Following these steps ensures that you have a fully functional Zabbix server to monitor your infrastructure effectively. If you encounter any issues, consult the Zabbix and PostgreSQL documentation for troubleshooting tips.

## Repository Context

This Zabbix module is part of the monitoring suite under `install-monitoring-tools/` in the Bash Automation Scripts Collection. For an overview of all modules, see the root [`README.md`](../../README.md) and the [`install-monitoring-tools/README.md`](../README.md).

