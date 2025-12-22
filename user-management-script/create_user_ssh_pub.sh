#!/bin/bash

# Set -e option ensures script exits immediately if any command returns a non-zero exit status.
set -e

# Prompt the administrator for username, password, and SSH public key path.
read -p "login:" login
read -p "password:" -s password
read -p "ssh public key path:" -e ssh_pub_path

# Define variables for home directory and SSH directory.
homedir=/home/$login
ssh_dir=$homedir/.ssh

# Create the SSH directory if it doesn't exist.
sudo mkdir -p "$ssh_dir"

# Append the content of the provided SSH public key file to authorized_keys.
sudo cat "$ssh_pub_path" >> "$ssh_dir/authorized_keys"

# Copy skeleton files from /etc/skel to the new user's home directory.
sudo cp -rT /etc/skel "$homedir"

# Add the new user with the specified home directory and shell.
sudo useradd -d $homedir -s /bin/bash $login

# Set ownership of the home directory to the new user.
sudo chown -R $login:$login $homedir

# Set the password for the new user.
echo "$login:$password" | sudo chpasswd

# Display the entry for the new user in the /etc/passwd file.
cat /etc/passwd | grep $login

