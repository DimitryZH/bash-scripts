# GCP Startup Script for Flask App

This directory contains a startup script designed to provision a Google Cloud Platform (GCP) Compute Engine instance to run a Flask application.

## Description

The `startup.sh` script performs the following actions:
1.  Updates the package list.
2.  Installs necessary system dependencies: `python3-pip`, `unzip`, `wget`, and `default-libmysqlclient-dev`.
3.  Creates a directory `/FlaskApp` to host the application.
4.  Downloads the application source code (`FlaskApp.zip`) from a specified Google Cloud Storage bucket.
5.  Unzips the application code.
6.  Installs Python dependencies listed in `requirements.txt`.
7.  Sets necessary environment variables.
8.  Starts the Flask application on port 80.

## Prerequisites

-   A Google Cloud Platform project.
-   A Google Cloud Storage bucket containing the `FlaskApp.zip` file.
-   The VM instance must have the necessary IAM scopes/permissions to access the GCS bucket (Storage Object Viewer).

## Configuration Variables

The script uses the following placeholders which must be replaced with actual values before execution (typically done via Terraform template rendering or manual substitution):

-   `${bucket_name}`: The name of the GCS bucket where `FlaskApp.zip` is stored.
-   `${project_id}`: The GCP Project ID.
-   `${flask_secret}`: The secret key for the Flask application.

## Environment Variables Set

The script exports the following environment variables for the Flask application:

-   `PHOTOS_BUCKET`: Set to `${bucket_name}`.
-   `GCP_PROJECT`: Set to `${project_id}`.
-   `DATASTORE_MODE`: Set to `on`.
-   `FLASK_SECRET`: Set to `${flask_secret}`.

## Usage

This script is intended to be used as a **Startup Script** for a GCP Compute Engine instance.

### Example with Terraform

If using Terraform, you can use the `templatefile` function to populate the variables:

```hcl
metadata_startup_script = templatefile("${path.module}/startup.sh", {
  bucket_name  = google_storage_bucket.app_bucket.name
  project_id   = var.project_id
  flask_secret = var.flask_secret
})
```

### Manual Usage

If running manually, ensure you replace the `${...}` placeholders with actual values in the script before running it on the server.

## Reference

This script is part of the **Employee Directory Cloud Migration Project**. You can find the full practical implementation and context in the following repository:

[Employee Directory Cloud Migration Project - GCP Implementation](https://github.com/DimitryZH/emp-app/tree/main/GCP)
