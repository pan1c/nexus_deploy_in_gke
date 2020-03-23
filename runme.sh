PROJECT_SERVICES="storage-component.googleapis.com firebasestorage.googleapis.com container.googleapis.com iam.googleapis.com iamcredentials.googleapis.com datastore.googleapis.com cloudbuild.googleapis.com"

SERVICE_ACC="nexus-blobstore"
SERVICE_ACCOUNT="${SERVICE_ACC}@${PROJECT_ID}.iam.gserviceaccount.com"

KEY_FOLDER=$HOME/.nexus-blobstore
KEY_FILE=${KEY_FOLDER}/${SERVICE_ACC}.json

CLUSTERNAME="nexus-cluster"

function prepare_project
{
    echo "First run initialization"
    echo "Project creating"
    gcloud projects create ${PROJECT_ID} || exit 1
    echo "Linking billing account"
    BILLING_ACC=`gcloud beta billing accounts list  --format='value(name)'`;
    gcloud beta billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACC}
    echo "Enabling neccessary google services"
    gcloud services enable $PROJECT_SERVICES;

}


function create_service_account
{
    echo "Creating service account"
    gcloud iam service-accounts create ${SERVICE_ACC}  --display-name "Service account for ${SERVICE_ACC}"
    gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:${SERVICE_ACCOUNT} --role roles/datastore.owner
    gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:${SERVICE_ACCOUNT} --role roles/storage.objectCreator
}

function apply_in_k8s 
{
    echo "Kubectl apply:"
    kubectl apply -f nexus3-data-persistentvolumeclaim.yaml
    kubectl apply -f nexus3-deployment.yaml
    kubectl apply -f nexus3-service.yaml
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
    echo "please specify google project id like PROJECT_ID=test1dfsfds ./$0"
    exit
fi

#If no project - create and prepare project
if gcloud projects list | grep -qoE "^$PROJECT_ID ";
then
    gcloud config set project "$PROJECT_ID" && echo "Switched to $PROJECT_ID" || exit 1
else
    prepare_project;
fi

#If no account - create account
if gcloud iam service-accounts list | grep -E "${SERVICE_ACCOUNT}";
then
    echo "Account_exist. Nice"
else
    create_service_account;
fi

#Create and save KEY_FILE for service account of needed
if ! [ -f "$KEY_FILE" ];
then
    gcloud iam service-accounts keys create $KEY_FILE --iam-account=${SERVICE_ACCOUNT}
else
    echo "Keyfile ( $KEY_FILE ) exists. Nice!"
fi

if ! gcloud container clusters list | grep -qoE "^${CLUSTERNAME} "
then
    gcloud container clusters create ${CLUSTERNAME}
else
echo "Cluster $CLUSTERNAME exists. Nice!"
fi;

echo "Add secrets from $KEY_FILE"
kubectl create secret generic nexus-blobstore --from-file /home/panic/.nexus-blobstore/nexus-blobstore.json

#wget https://raw.githubusercontent.com/sonatype-nexus-community/nexus-blobstore-google-cloud/master/docker-compose.yml

echo "Download new Dockerfile"
[[ ! -f "Dockerfile" ]] && wget https://raw.githubusercontent.com/sonatype-nexus-community/nexus-blobstore-google-cloud/master/Dockerfile -O Dockerfile

gcloud builds list
echo "Build new image from Dockerfile"
docker build . --tag gcr.io/${PROJECT_ID}/nexus3
#Same in goole
#gcloud builds submit --tag gcr.io/test1dfsfds/nexus3
apply_in_k8s;