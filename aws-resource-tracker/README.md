# AWS Resource Tracker

The AWS Resource Tracker is a shell script designed to generate a detailed report of AWS resource usage across various services. It provides a snapshot of the current state of resources, making it an invaluable tool for administrators and developers who need to monitor and manage AWS infrastructure efficiently.

## Features

- **Coverage**: Tracks resources from a wide range of AWS services including S3, EC2, Lambda, IAM, DynamoDB, Route53, AWS Amplify, and EKS.
- **Detailed Reporting**: Outputs a detailed report that includes information such as instance IDs, types, states, creation times, and more for EC2 instances; function names, runtimes, and last modified times for Lambda functions; user names, IDs, and creation dates for IAM users; and similar detailed information for other tracked services.
- **Region-Specific Tracking**: Allows specifying the AWS region to focus the tracking on resources located in a particular region.

## Usage

1. Ensure you have AWS CLI and jq installed on your system.
2. Clone this repository or download the `resource_tracker.sh` script.
3. Make the script executable: `chmod +x resource_tracker.sh`.
4. Run the script: `./resource_tracker.sh`.
5. Check the generated report named `resourceTracker` for the output.

## Prerequisites

- AWS CLI configured with appropriate permissions to list resources across the services mentioned.
- jq for parsing and formatting the output from AWS CLI commands.

## Output

The script generates a report named `resourceTracker`, which includes sections for each AWS service covered. Each section contains a list of resources with relevant details, making it easy to understand the current resource utilization and configurations.

## Customization

You can customize the script by modifying the `region` variable to track resources in a different AWS region or by adding/removing sections to include other AWS services as per your requirements.
