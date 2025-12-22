#!/bin/bash
###################################################
# This script reports resource usage on AWS
#
## Track
# AWS S3
# AWS Lambda
# AWS EC2
# IAM Users
# DynamoDB
# Route53
# AWS Amplify
# EKS
####################################

echo "Current Date and Time: $(date)"

set -x

# Create output file and add a header
output_file="resourceTracker"
echo "AWS Resource Tracker Report" > $output_file
echo "Generated on: $(date)" >> $output_file
echo "========================================" >> $output_file

# Function to add a section header
add_section_header() {
    echo -e "\n\n####################################" >> $output_file
    echo -e "# $1" >> $output_file
    echo "####################################" >> $output_file
}

# Specify your default AWS region
region="us-east-1"

# List all S3 Buckets
add_section_header "S3 Buckets"
echo "Listing all S3 buckets:" >> $output_file
aws s3 ls >> $output_file

# List all EC2 instances
add_section_header "EC2 Instances"
echo "Listing all EC2 instances:" >> $output_file

# Define headers
echo "InstanceID   InstanceType    State    LaunchTime     AvailabilityZone    PlatformDetails     Name" >> $output_file

# Append AWS EC2 instances information with headers
aws ec2 describe-instances --region $region | jq -r '.Reservations[].Instances[] | "\(.InstanceId) \(.InstanceType) \(.State.Name) \(.LaunchTime) \(.Placement.AvailabilityZone) \(.PlatformDetails) \(.Tags[] | select(.Key=="Name").Value)"' >> $output_file

# List Lambda Functions
add_section_header "Lambda Functions"
echo "Listing all Lambda functions:" >> $output_file
aws lambda list-functions --region $region | jq -r '.Functions[] | "\(.FunctionName) \(.Runtime) \(.LastModified)"' >> $output_file

# List IAM Users
add_section_header "IAM Users"
echo "Listing all IAM users:" >> $output_file
aws iam list-users --region $region | jq -r '.Users[] | "\(.UserName) \(.UserId) \(.CreateDate)"' >> $output_file

# List DynamoDB Tables
add_section_header "DynamoDB Tables"
echo "Listing all DynamoDB tables:" >> $output_file
aws dynamodb list-tables --region $region | jq -r '.TableNames[]' >> $output_file

# List Route53 Hosted Zones
add_section_header "Route53 Hosted Zones"
echo "Listing all Route53 hosted zones:" >> $output_file
aws route53 list-hosted-zones --region $region | jq -r '.HostedZones[] | "\(.Id) \(.Name) \(.ResourceRecordSetCount)"' >> $output_file

# List AWS Amplify Apps
add_section_header "AWS Amplify Apps"
echo "Listing all AWS Amplify apps:" >> $output_file
aws amplify list-apps --region $region | jq -r '.apps[] | "\(.appId) \(.name) \(.createTime) \(.updateTime)"' >> $output_file

# List EKS Clusters
add_section_header "EKS Clusters"
echo "Listing all EKS clusters:" >> $output_file
aws eks list-clusters --region $region | jq -r '.clusters[]' >> $output_file

echo "AWS resource tracking complete. Results are stored in $output_file"
