# Bash Backup Automation

Bash Backup Automation is a bash script designed to automate the process of backing up files and directories on Unix-based systems. This script ensures your important data is securely archived with features such as compression, logging, error handling, and interrupt handling.

## Features

- **Automated Backups**: Automatically create backups of specified directories.
- **Compression**: Compress backups using tar and gzip to save space.
- **Logging**: Detailed logging of backup activities and errors.
- **Error Handling**: Robust error handling to ensure reliability.
- **Interrupt Handling**: Gracefully handle interruptions (Ctrl+C) to clean up partially completed backups.

### Implementation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/DimitryZH/bash-backup-automation.git
   cd bash-backup-automation
   ```
2. **Make the Script Executable**:
    ```bash
    chmod +x backup_script.sh
    ```
3. **Usage**:
     Run the script with a log file parameter:
   ```bash
   ./backup_script.sh /path/to/your/logfile.log
    ```
4. **Example**
   An example of running the script:
   ```bash
   ./backup_script.sh /home/dmitry/backup.log
   ```
This will:
Create a backup directory named projects_backup in the user's home directory.
Copy all files from the projects directory to the projects_backup directory.
Compress the projects_backup directory into a tar.gz archive.
Log all activities and errors into the specified log file.

## Results
![backup-script-results](https://github.com/DimitryZH/bash-backup-automation/assets/146372946/a41bf8b7-966f-4f6f-bea6-7831712844fd)

## Contributing

Contributions are welcome!
