# nexus_deploy_in_gke

Synopsis
----------

This script can install nexus3 with nexus-blobstore-google-cloud from zero. It will be installed in GKE.

Prerequisites
----------

- Clone repo
- Install gcloud tools
- Run gcloud init

Installing
----------
```
PROJECT_ID=test1dfsfds ./runme.sh
```
Where PROJECT_ID is GCE project_id (existing\or not)
This script is idempotent so you can run it more the one time.

Postinstall
----------
- As described [here](https://github.com/sonatype-nexus-community/nexus-blobstore-google-cloud):
Firestore usage is exclusively in Datastore mode; you must configure the project for your Repository Manager deployment
to use ["Firestore in Datastore mode"](https://cloud.google.com/firestore/docs/firestore-or-datastore). You should do it via [google cloud web interface](https://console.cloud.google.com/firestore) manually after deployment.

- Script will create new storage bucket with name: ${PROJECT_ID}-nexus-plugin-bucket please use it as Google Cloud Bucket Name in plugin configuration.
