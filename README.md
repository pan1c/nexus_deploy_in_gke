# nexus_deploy_in_gke


This script can install nexus3 with nexus-blobstore-google-cloud from zero. It will be installed in GKE.

To do that:

- Clone repo
- Install docker-ce, or change script to use google cloud build
- Install gcloud tools
- Run gcloud init
- As described [here](https://github.com/sonatype-nexus-community/nexus-blobstore-google-cloud):
Firestore usage is exclusively in Datastore mode; you must configure the project for your Repository Manager deployment
to use ["Firestore in Datastore mode"](https://cloud.google.com/firestore/docs/firestore-or-datastore). You should do it via google cloud web interface manually.

Then run script as described:

```
PROJECT_ID=test1dfsfds ./runme.sh
```
Where PROJECT_ID is GCE project_id (existing\or not)
