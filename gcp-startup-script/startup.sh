#!/bin/bash
apt-get update
apt-get install -y python3-pip unzip wget default-libmysqlclient-dev
mkdir -p /FlaskApp
cd /FlaskApp
gsutil cp gs://${bucket_name}/FlaskApp.zip .
unzip -o FlaskApp.zip
pip3 install -r requirements.txt
export PHOTOS_BUCKET=${bucket_name}
export GCP_PROJECT=${project_id}
export DATASTORE_MODE=on
export FLASK_SECRET=${flask_secret}
FLASK_APP=application.py /usr/local/bin/flask run --host=0.0.0.0 --port=80
