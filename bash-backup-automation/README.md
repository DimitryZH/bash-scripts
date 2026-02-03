# Bash Backup Automation

Bash Backup Automation is a Bash script designed to automate the process of backing up files and directories on Unix-based systems. This script ensures your important data is securely archived with features such as compression, logging, error handling, and interrupt handling.

## Features

- **Automated Backups**: Automatically create backups of specified directories.
- **Compression**: Compress backups using `tar` and `gzip` to save space.
- **Logging**: Detailed logging of backup activities and errors.
- **Error Handling**: Robust error handling to ensure reliability.
- **Interrupt Handling**: Gracefully handle interruptions (Ctrl+C) to clean up partially completed backups.

## Usage

### From this repository

1. Clone the Bash Automation Scripts Collection and navigate to this module:

   ```bash
   git clone https://github.com/your-username/bash-scripts.git
   cd bash-scripts/bash-backup-automation
   ```

2. Make the script executable:

   ```bash
   chmod +x backup_script.sh
   ```

3. Run the script with a log file parameter:

   ```bash
   ./backup_script.sh /path/to/your/logfile.log
   ```

4. Example:

   ```bash
   ./backup_script.sh /home/dmitry/backup.log
   ```

This will:

- Create a backup directory named `projects_backup` in the user's home directory.
- Copy all files from the `projects` directory to the `projects_backup` directory.
- Compress the `projects_backup` directory into a `.tar.gz` archive.
- Log all activities and errors into the specified log file.

### Original standalone repository

This script was originally developed and documented in its own repository:

- https://github.com/DimitryZH/bash-backup-automation

That repository includes additional screenshots and context. The copy in this collection is intended for use alongside the other automation scripts.

## Results

![backup-script-results](https://github.com/DimitryZH/bash-backup-automation/assets/146372946/a41bf8b7-966f-4f6f-bea6-7831712844fd)

## Repository Context

This directory is part of the Bash Automation Scripts Collection. For an overview of all modules and contribution guidelines, see the root [`README.md`](../README.md).

