# Setup of custom workstations image
<https://cloud.google.com/workstations/docs/customize-container-images#sample_custom_dockerfiles>
<https://github.com/mchmarny/custom-cloud-workstation-image/blob/main/Dockerfile>
<https://cloud.google.com/build/docs/build-push-docker-image#:~:text=Guide%20me-,Before%20you%20begin,Dark%20code%20theme>
https://docs.cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling#auth

-------------------------------------------------
## Step 1: Create a custom image container for use in workstations

# Initial Terraform Step: create repository for image (workstations.tf)
1. Create Artifact Registry repository is set up or create one to hold the images (Terraform Artifact Registry repository)
2. Add "roles/workstations.operationViewer" role to project user group IAM permissions

# Cloud Build Step: create image
1. Update the Dockerfile as needed (or create a new one).
2. In the Cloud Shell terminal, navigate to the Dockerfile location.
3. Build the image using Cloud Build and push it to Artifact Registry.
    - need the region, project_id, repository, and image_name (project_id and repository can be found in the repo link).
    - cd <Dockerfile folder>
    * Run these commands first
    - gcloud auth login
    - gcloud auth configure-docker us-east4-docker.pkg.dev
    - gcloud config set project <project-id>
    * Build image
    - gcloud builds submit --region=<region> --tag <region>-docker.pkg.dev/<project-id>/<repository>/<image-name>:latest
    Example: gcloud builds submit --region=us-east4 --tag us-east4-docker.pkg.dev/usfs-poc-003b/workstation-repo/gcp-ws:latest
4. The image should be built, pushed to Artifact Registry, and ready to use.    

# Additional Terraform Steps (workstations.tf)
1. Create workstation service account and assign permissions. 
2. Create a new workstation configuration from the image.
    - Ensure the settings are correct, the project network is used, and public ip is disabled.
3. Create a workstation and ensure libraries are set up correctly.

-------------------------------------------------
## Update an existing workstation image
Should be able to update the Dockerfile and create a new image.
Config is set to :latest image, so when images update when users start up a workstation they should
get the latest image if a new image has been pushed.
Could explore scheduling image creation to pick up any base image updates.
https://medium.com/@jaysonbh-g/how-to-use-the-latest-cloud-workstation-custom-image-962a2c1e37a4

-------------------------------------------------
## Current workstation images
1. folder admin-compute/cloudshell_workstation_2025-04-28
    - original image set up by Joel Thompson
    - a Custom image to mimic Cloud Shell
    - install terraform and GitHub CLI (gh)
    - After creating a workstation, run some tests.
        - terraform --version
        - gh --version
2. folder admin-compute/cloudshell_workstation_2025-10-22
    - added python3, python3-pip, python3.12-venv
    - enables creation of virtual environment in workstation
    - add additional python packages to virtual environment

-------------------------------------------------
## Actions when logging in to new workstation for the first time
It is best to add additional packages to a workstation through a virtual environment.
When logging in to a new workstation for the first time, do the following:

1. Authenticate gcloud
gcloud auth application-default login
gcloud auth application-default set-quota-project <project-id>
gcloud auth login
gcloud config set project <project-id>

2. Authenticate GitHub Enterprise
gh auth login
GitHub Enterprise Server (may need to select Other, then input address below)
code.fs.usda.gov
HTTPS
Paste authentication token
Paste your authentication token: <token>

git config --global user.name "user-name"
git config --global user.email "<email>@usda.gov"

3. Create virtual environment (in $HOME) and install packages
python3 -m venv gcp_env
source /home/user/gcp_env/bin/activate

pip install 
google-cloud-resource-manager 
google-cloud-storage 
google-cloud-iam 
google-cloud-compute 
google-api-python-client 
earthengine-api --upgrade
pandas 
openpyxl 
google-cloud-asset 
google-cloud-service-usage 
google-cloud-billing

4. List packages installed
pip list

5. Deactivate virtual environment
deactivate

-------------------------------------------------

