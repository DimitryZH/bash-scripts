# Bash Scripts Collection

This repository serves as a centralized library of shell scripts designed to automate a wide range of tasks, including cloud infrastructure management, system administration, and DevOps workflows.

## Repository Structure

| Module | Documentation | Description |
| :--- | :--- | :--- |
| `aws-resource-tracker` | [README](aws-resource-tracker/README.md) | Scripts to track and report on AWS resources (S3, EC2, IAM, Lambda). |
| `bash-backup-automation` | [README](bash-backup-automation/README.md) | Automation scripts for performing system or file backups with scheduling. |
| `gcp-startup-script` | [README](gcp-startup-script/README.md) | Startup scripts for provisioning GCP Compute Engine instances. |
| `install-ubuntu-packages` | [README](install-ubuntu-packages/README.md) | Utilities for bootstrapping Ubuntu systems and installing common packages. |
| `user-management-script` | [README](user-management-script/README.md) | Scripts for managing system users, SSH keys, and permissions. |

## Getting Started

To use any of the scripts in this repository, clone the repo to your local machine or server:

```bash
git clone https://github.com/your-username/bash-scripts.git
cd bash-scripts
```

Navigate to the specific directory of the script you wish to use and refer to its local `README.md` for detailed instructions.

## Prerequisites

Depending on the script you intend to run, you may need the following tools installed:

-   **Bash**: Most scripts are written for the Bash shell.
-   **AWS CLI**: For `aws-resource-tracker`.
-   **Google Cloud SDK**: For `gcp-startup-script` interactions.
-   **Git**: For version control operations.

## Contributing

Contributions are welcome! If you have a useful script to add or an improvement to an existing one:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/new-script`).
3.  Commit your changes.
4.  Push to the branch.
5.  Open a Pull Request.

## License

Please refer to the `LICENSE` files in specific subdirectories for licensing information regarding individual scripts.
