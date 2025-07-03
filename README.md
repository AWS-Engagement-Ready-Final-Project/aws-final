# AWS Engagement Ready Program - Final Project
Collaborators: Avery Bolingbroke, William Burgis, Thomas Watkins

## Table of Contents

- [Objectives](#objectives)
- [Initial Requirements](#initial-requirements)
- [Initial Setup](#initial-setup)
- [Testing Pipeline](#testing-pipeline)

## Objectives
1. Design an application and infrastructure in AWS
1. Containerize and test your application to work in an AWS environment
1. Automate the construction of the infrastructure/application using infastructure as code
1. Build a CI/CD pipeline
1. Test pipeline with a Blue/Green deployment and a rolling update

## Initial Requirements

In order to run test this application, you will need to have the following:
1. A GitHub account and this repository to be forked somewhere that you can make changes to its settings
2. An AWS server set up with Docker, Node, AWS CLI, eksctl/kubectl, Java, and Jenkins installed, as explained in the Activity 7 instructions for the course

Ensure that your Jenkins server has all of the necessary pipeline and GitHub plugins installed, including the following:
- AWS Credentials Plugin
- Configuration as Code Plugin
- Credentials Plugin
- Credentials Binding Plugin
- Docker API Plugin
- Docker Commons Plugin
- Docker Pipeline
- Docker Plugin
- Git Plugin
- GitHub API Plugin
- GitHub Branch Source Plugin
- GitHub Integration Plugin
- Pipeline
- Pipeline Utility Steps
- Pipeline: API
- Pipeline: Basic Steps
- Pipeline: Build Step
- Pipeline: Declarative
- Pipeline: GitHub
- Pipeline: Groovy
- Pipeline: Input Step
- Pipeline: Job
- Pipeline: SCM Step
- Pipeline: Stage Step
- Pipeline: Step API
and all recommended plugins

## Initial Setup

### Configuring GitHub Jenkins WebHook
1. Enter the repo settings and click "Webhooks".
2. Click "Add webhook".
3. Under the Payload URL, enter `http://<jenkins-server-public-dns>:8080/github-webhook`, replacing `<jenkins-server-public-dns>` with the public DNS of your Jenkins server (e.g. `ec2-54-86-247-186.compute-1.amazonaws.com`).
4. Select `application/json` for the content type.
5. Create the webhook.

### Configuring Jenkins Credentials
1. In `Manage Jenkins` -> `Credentials`, navigate to the `System` Store -> `Global credentials (unrestricted)`, and add the following credentials:
    1. AWS access key
        - Kind: `AWS Credentials`
        - ID: `aws-creds`
        - Access Key ID: `<your access key id>`
        - Secret Access Key: `<your secret access key>`

### Setting Up the Pipeline in Jenkins
1. Make sure initial requirements are taking care of.
2. Log into your Jenkins server as the admin user.
3. From the main Dashboard, click "New Item". Then click "Pipeline" and give the pipeline a name (e.g. full-devops-pipeline).
4. In the "General" section, give the pipeline a description and check the "GitHub Project" box. Paste `https://github.com/AWS-Engagement-Ready-Final-Project/aws-final` into the "Project url" field (or the URL of your forked repo).
5. In the "Triggers" section, select "GitHub hook trigger for GITScm polling".
6. In the "Pipeline" section, select "Pipeline script from SCM." Under "SCM" choose "Git" and then paste `https://github.com/AWS-Engagement-Ready-Final-Project/aws-final` (or the name of your forked repo) into the "Repository URL" field. For the "Branch Specifier", enter `*/main` and ensure `Jenkinsfile` is the value for "Script Path".
7. Click "Save".

### Initial Kubernetes Setup
1.  Navigate to the `kubernetes-config` directory in this repository: `cd kubernetes-config`.
2. Run the following command to create a new cluster and associated resources for it using EKSCTL: `eksctl create cluster -f cluster.yaml`.
3. Wait for all resources to spin up successfully without error messages.
4. Install MariaDB with a helm chart by running `helm install database-server oci://registry-1.docker.io/bitnamicharts/mariadb`.
5. Run the following command to make gp2 the default storage class so the persistent volume claim can be applied correctly for the DB when it comes up: `kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`
6. Create the API and website deployments by running `kubectl apply -f api-deployment.yaml` and `kubectl apply -f web-deployment.yaml`. Ensure 3 pods for each come up successfully, and one pod for the database.
7. Create the API and website services by running `kubectl apply -f api-service.yaml` and `kubectl apply -f web-service.yaml`. Ensure the services come up successfully.
8. Run `kubectl apply -f autoscale.yaml` to enable autoscaling for the web deployment.
9. Run `kubectl apply -f db_init_job.yaml` to intialize the database.

## Testing Pipeline

Though this pipeline can be tested in a variety of ways, try attempting the following scenarios:
1. Trigger the pipeline manually from the Jenkins UI. Verify it finishes successfully and that new deployments are created and activated by the services, but new images are not built or pushed.
2. Make a change to the codebase (not in the frontend or backend directory) and push it to GitHub. Verify the pipeline is automatically triggered, no builds or pushes take place, and no new Kubernetes deployments are created.
3. Make a change in the backend directory and push it to GitHub. Verify the pipeline is automatically triggered, a new backend image with a new tag is built and pushed, and a new backend deployment is created that the backend service is updated with.
4. Make a change in the `frontend/views/layouts/default.hbs` file's header (line 16) and push it to GitHub. Verify the pipeline is automatically triggered, a new frontend image with a new tag is built and pushed, and a new frontend deployment is created that the frontend service is updated with. Also verify the change has taken place in the UI of your application.
5. Attempt any other changes you would like to be tested.
