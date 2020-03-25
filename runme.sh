PROJECT_SERVICES="cloudapis.googleapis.com storage-component.googleapis.com firebasestorage.googleapis.com container.googleapis.com iam.googleapis.com iamcredentials.googleapis.com datastore.googleapis.com cloudbuild.googleapis.com"

SERVICE_ACC="nexus-blobstore"
SERVICE_ACCOUNT="${SERVICE_ACC}@${PROJECT_ID}.iam.gserviceaccount.com"

KEY_FOLDER=$HOME/.nexus-blobstore
KEY_FILE=${KEY_FOLDER}/${SERVICE_ACC}.json

CLUSTERNAME="nexus-cluster"
DEFAULTZONE="europe-west4-c"

function prepare_project
{
    echo "First run initialization"
    echo "Project creating"
    gcloud projects create ${PROJECT_ID} || exit 1
    echo "Linking billing account"
    BILLING_ACC=`gcloud beta billing accounts list  --format='value(name)'`;
    gcloud beta billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACC}
    sleep 1
    echo "Enabling neccessary google services"
    echo  "gcloud services enable $PROJECT_SERVICES;"
    gcloud services enable $PROJECT_SERVICES;
}


function create_service_account
{
    echo "Creating service account"
    gcloud iam service-accounts create ${SERVICE_ACC}  --display-name "Service account for ${SERVICE_ACC}"
    gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:${SERVICE_ACCOUNT} --role roles/datastore.owner
    gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:${SERVICE_ACCOUNT} --role roles/storage.admin
}

function create_and_add_secrets
{
    echo "Store secret key"
    gcloud iam service-accounts keys create $KEY_FILE --iam-account=${SERVICE_ACCOUNT}
    echo "Add secrets from $KEY_FILE"
    kubectl create secret generic nexus-blobstore --from-file /home/panic/.nexus-blobstore/nexus-blobstore.json
    rm -f $KEY_FILE
}


function apply_in_k8s 
{
    echo "Kubectl apply:"
    kubectl apply -f $(dirname "$0")/k8s -R
}

function prepare_k8s_files
{
    echo "Edit deployment file to setup correct project_id"
    cp -f $(dirname "$0")/k8s/nexus-deployment.yaml.template $(dirname "$0")/k8s/nexus-deployment.yaml
    sed "s/{{PROJECT_ID}}/${PROJECT_ID}/g" -i $(dirname "$0")/k8s/nexus-deployment.yaml
}


################################################ START
mkdir -p $KEY_FOLDER


#Is gcloud initilized?
if [ ! -d $HOME/.config/gcloud/ ]; then
    echo "Please do gcloud init before using this";
    echo "gcloud init"
    exit
fi

#Is PROJECT_ID set?
if [[ -z $PROJECT_ID ]];
then 
    echo "please specify google project id like PROJECT_ID=test1dfsfds $0"
    exit
fi

#If no project - create and prepare project
if ! gcloud projects list | grep -qoE "^$PROJECT_ID ";
then
    prepare_project;
fi

#Switch to the project
gcloud config set project "$PROJECT_ID" && echo "Switched to $PROJECT_ID" || exit 1

#set zone if needed
ZONE=$(gcloud config get-value zone) ;
[[ -z $ZONE ]] && ZONE=$DEFAULTZONE

#If no account - create account
if gcloud iam service-accounts list | grep -E "${SERVICE_ACCOUNT}";
then
    echo "Account exists. Nice"
else
    create_service_account;
fi

#Create k8s cluster if needed
if ! gcloud container clusters list | grep -qoE "^${CLUSTERNAME} "
then
    gcloud container clusters create ${CLUSTERNAME} --zone=${ZONE} || exit 1
else
    echo "Cluster $CLUSTERNAME exists. Nice!"
fi;

echo get kubectl credentials for cluster
gcloud container clusters get-credentials ${CLUSTERNAME} --zone=${ZONE}

#Add secrets if needed
if ! kubectl get secrets | grep -qoE "^nexus-blobstore "
then

create_and_add_secrets;

else
    echo "Secret (nexus-blobstore) exists. Nice!"
fi

#Download new Dockerfile if needed
echo "Will use existing Dockerfile, if you want to use new Dockerfile from sonatype-nexus-community - please delete existing"
[[ ! -f "Dockerfile" ]] && wget https://raw.githubusercontent.com/sonatype-nexus-community/nexus-blobstore-google-cloud/master/Dockerfile -O Dockerfile

#echo "Build new image from Dockerfile"
#docker build . --tag gcr.io/${PROJECT_ID}/nexus3
#

echo "Build new image from Dockerfile using google builds"
gcloud builds submit --tag gcr.io/${PROJECT_ID}/nexus3

#Deploy in k8s
prepare_k8s_files;

apply_in_k8s;

echo "This will create new bucket: $PROJECT_ID-nexus-plugin"
echo "Please use it in plugin configuration"
gsutil mb gs://${PROJECT_ID}-nexus-plugin-bucket/
