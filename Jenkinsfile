/*
 * Jenkinsfile for building and deploying the events-app project.
 * This pipeline builds Docker images for the frontend and backend, pushes them to a specified repository,
 * and deploys the application to an EKS cluster using Helm.
 */

pipeline {
    agent any

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region for all resources')
        string(name: 'AWS_CREDENTIALS_ID', defaultValue: 'aws-credentials', description: 'The ID of a Credentials resource for AWS (expecting kind AWS Credentials)')
        string(name: 'FRONTEND_IMAGE_REPO', defaultValue: 'wburgis/devops-er-frontend', description: 'The repo to push the events-app frontend image to')
        string(name: 'BACKEND_IMAGE_REPO', defaultValue: 'wburgis/devops-er-backend', description: 'The repo to push the events-app backend image to')
        string(name: 'DB_INIT_IMAGE_REPO', defaultValue: '360990851379.dkr.ecr.us-east-1.amazonaws.com/events-job', description: 'The repo to pull the events-app db-init job from')
        choice(name: 'IMAGE_REPO_TYPE', choices: ['dockerhub', 'ecr'], description: 'The type of image repository to use (dockerhub[default] or ecr)')
        string(name: 'DOCKERHUB_CREDENTIALS_ID', defaultValue: '5cd81998-a923-4dc4-8b0c-a3d5239f9661', description: 'The credentials to authenticate with DockerHub (if using dockerhub as the image repo type)')
        booleanParam(name: 'SHOULD_BUILD_IMAGES', defaultValue: true, description: 'Whether this pipeline should build new images before deploying')
        // in a real-world pipeline, the code for these images would live in separate repos and be versioned independently
        string(name: 'FRONTEND_VERSION_TAG', defaultValue: '1.0', description: 'The version tag to use to build and pull the frontend docker image')
        string(name: 'BACKEND_VERSION_TAG', defaultValue: '1.0', description: 'The version tag to use to build and pull the backend docker image')
        string(name: 'DB_INIT_VERSION_TAG', defaultValue: '1.0', description: 'The version tag to use to build and pull the db_init docker image')
    }

    environment {
        PLATFORM = 'linux_amd64'
        BIN_PATH = '/var/lib/jenkins/.local/bin'
        AWS_REGION = "${params.AWS_REGION}"
        AWS_CREDENTIALS_ID = "${params.AWS_CREDENTIALS_ID}"
    }

    stages {
        stage('Configure AWS Credentials') {
            steps {
                withCredentials([aws(credentialsId: "$AWS_CREDENTIALS_ID", accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        echo "Configuring AWS credentials"
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set region $AWS_REGION
                        echo "AWS credentials configured"
                    '''
                }
            }
        }

        stage('Install kubectl') {
            steps {
                echo "Installing kubectl"
                sh 'curl -O "https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2025-05-01/bin/linux/amd64/kubectl"'
                sh 'chmod +x ./kubectl'
                sh 'mkdir -p ~/.local/bin'
                sh 'mv ./kubectl ~/.local/bin/kubectl'
                echo "Getting kubectl version"
                sh '${BIN_PATH}/kubectl version --client=true'
            }
        }

        stage('Install eksctl') {
            steps {
                script {
                    echo "Installing eksctl"
                    sh 'curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz"'
                    sh 'tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz'
                    sh 'mv /tmp/eksctl ~/.local/bin/eksctl'
                    echo "Getting eksctl version"
                    sh '${BIN_PATH}/eksctl version'
                }
            }
        }

        stage('Install helm') {
            steps {
                script {
                    echo "Installing helm"
                    sh 'curl -sLO "https://get.helm.sh/helm-v3.18.3-linux-amd64.tar.gz"'
                    sh 'tar -xzf helm-v3.18.3-linux-amd64.tar.gz -C /tmp && rm helm-v3.18.3-linux-amd64.tar.gz'
                    sh 'mv /tmp/linux-amd64/helm ~/.local/bin/helm'
                    echo "Getting helm version"
                    sh '${BIN_PATH}/helm version'
                }
            }
        }

        stage('Clone the devops repo') {
            steps {
                echo 'Cloning devops project repository'
                git branch: env.BRANCH_NAME ?: 'main',
                    url: 'https://github.com/AWS-Engagement-Ready-Final-Project/aws-final.git'
                echo 'Was repo cloned?'
                sh 'ls -a'
            }
        }

        stage('Pre-check: Code Quality & Security') {
            steps {
                script {
                    def checks = [
                        [job: 'hadolint-scan-pipeline',  params: [string(name: 'DOCKERFILE_PATH', value: 'frontend/Dockerfile')]],
                        [job: 'hadolint-scan-pipeline',  params: [string(name: 'DOCKERFILE_PATH', value: 'backend/Dockerfile')]],
                        [job: 'yamllint-scan-pipeline',  params: [string(name: 'YAML_DIR', value: 'helm/events-app')]],
                        [job: 'checkov-scan-pipeline',   params: [string(name: 'IAC_DIR', value: 'helm/events-app')]],
                        [job: 'jslint-scan-pipeline',    params: [string(name: 'SOURCE_DIR', value: 'frontend')]],
                        [job: 'npm-audit-scan-pipeline', params: [string(name: 'SOURCE_DIR', value: 'frontend')]],
                        [job: 'js-test-pipeline',        params: [string(name: 'SOURCE_DIR', value: 'frontend')]]
                    ]
                    for (check in checks) {
                        build job: check.job, parameters: check.params, wait: true
                    }
                }
            }
        }

        stage('Build backend Docker image') {
            when {
                expression { params.SHOULD_BUILD_IMAGES }
            }
            steps {
                script {
                    echo 'Building backend Docker image'
                    dir('backend') {
                        sh "docker build -t ${params.BACKEND_IMAGE_REPO}:${params.BACKEND_VERSION_TAG} ."
                    }
                }
            }
        }

        stage('Push backend Docker image to dockerhub') {
            when {
                expression { params.SHOULD_BUILD_IMAGES && params.IMAGE_REPO_TYPE == 'dockerhub'}
            }
            steps {
                withCredentials([usernamePassword(credentialsId: params.DOCKERHUB_CREDENTIALS_ID, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${params.BACKEND_IMAGE_REPO}:${params.BACKEND_VERSION_TAG}
                    """
                }
            }
        }

        stage('Push backend Docker image to ecr') {
            when {
                expression { params.SHOULD_BUILD_IMAGES && params.IMAGE_REPO_TYPE == 'ecr'}
            }
            steps {
                sh "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${params.BACKEND_IMAGE_REPO}"
                sh "docker push ${params.BACKEND_IMAGE_REPO}:${params.BACKEND_VERSION_TAG}"
            }
        }

        stage('Build frontend Docker image') {
            when {
                expression { params.SHOULD_BUILD_IMAGES }
            }
            steps {
                script {
                    echo 'Building frontend Docker image'
                    dir('frontend') {
                        sh "docker build -t ${params.FRONTEND_IMAGE_REPO}:${params.FRONTEND_VERSION_TAG} ."
                    }
                }
            }
        }

         stage('Scan frontend Docker image with Trivy') {
            steps {
                script {
                    build job: 'trivy-scan-pipeline',
                        parameters: [
                            string(name: 'IMAGE', value: "${params.FRONTEND_IMAGE_REPO}:${params.FRONTEND_VERSION_TAG}")
                        ],
                        wait: true
                }
            }
        }

        stage('Push frontend Docker image to dockerhub') {
            when {
                expression { params.SHOULD_BUILD_IMAGES && params.IMAGE_REPO_TYPE == 'dockerhub'}
            }
            steps {
                withCredentials([usernamePassword(credentialsId: params.DOCKERHUB_CREDENTIALS_ID, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${params.FRONTEND_IMAGE_REPO}:${params.FRONTEND_VERSION_TAG}
                    """
                }
            }
        }

        stage('Push frontend Docker image to ecr') {
            when {
                expression { params.SHOULD_BUILD_IMAGES && params.IMAGE_REPO_TYPE == 'ecr'}
            }
            steps {
                sh "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${params.FRONTEND_IMAGE_REPO}"
                sh "docker push ${params.FRONTEND_IMAGE_REPO}:${params.FRONTEND_VERSION_TAG}"
            }
        }

        stage('Build db-init Docker image') {
            when {
                expression { params.SHOULD_BUILD_IMAGES }
            }
            steps {
                script {
                    echo 'Building db-init Docker image'
                    dir('database-initializer') {
                        sh "docker build -t ${params.DB_INIT_IMAGE_REPO}:${params.DB_INIT_VERSION_TAG} ."
                    }
                }
            }
        }

        stage('Scan backend Docker image with Trivy') {
            steps {
                script {
                    def imageToScan = "${params.BACKEND_IMAGE_REPO}:${params.BACKEND_VERSION_TAG}"
                    echo "🎯 About to scan backend image: ${imageToScan}"

                    build job: 'trivy-scan-pipeline',
                        parameters: [
                            string(name: 'IMAGE', value: imageToScan)
                        ],
                        wait: true
                }
            }
        }

        //dockerhub push ommitted because wburgis does not have a repo for db-init

        stage('Push db-init Docker image to ecr') {
            when {
                expression { params.SHOULD_BUILD_IMAGES && params.IMAGE_REPO_TYPE == 'ecr'}
            }
            steps {
                sh "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${params.DB_INIT_IMAGE_REPO}"
                sh "docker push ${params.DB_INIT_IMAGE_REPO}:${params.DB_INIT_VERSION_TAG}"
            }
        }


        stage('Create EKS Cluster') {
            when {
                expression {
                    // check if the cluster exists, if it does, skip this stage
                    try {
                        sh 'aws eks describe-cluster --name aws-final-capstone --region $AWS_REGION'
                        catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') {
                            // if the cluster exists, this will not throw an error
                            echo "EKS Cluster already exists, skipping creation"
                            // return false to skip the stage
                            return false
                        }
                        return false // cluster exists, skip creation
                    } catch (Exception e) {
                        return true // cluster does not exist, proceed with creation
                    }
                }
            }
            steps {
                echo "Creating EKS Cluster"
                sh '${BIN_PATH}/eksctl create cluster -f eks/cluster.yaml'
            }
        }

        stage("Patch EKS storageclass") {
            steps {
                script {
                    echo "Patching EKS storageclass"
                    sh '''
                        ${BIN_PATH}/kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
                    '''
                }
            }
        }

        stage("Check for helm installation") {
            steps {
                script {
                    try {
                        sh '${BIN_PATH}/helm status events-app'
                        echo "events-app already installed"
                        env.EVENTS_APP_EXISTS = 'true'
                    } catch (Exception e) {
                        echo "events-app not yet installed"
                        env.EVENTS_APP_EXISTS = 'false'
                    }
                }
            }

        }
        stage("Deploy events-app") {
            steps {
                dir("helm/events-app") {
                    script {
                        sh '${BIN_PATH}/helm dependency update'
                        if (env.EVENTS_APP_EXISTS == 'false') {
                            try {
                                sh """
                                ${BIN_PATH}/helm install events-app . -f values.yaml \
                                --set website.image.tag="${params.FRONTEND_VERSION_TAG}" \
                                --set website.image.repository="${params.FRONTEND_IMAGE_REPO}" \
                                --set api.image.tag="${params.BACKEND_VERSION_TAG}" \
                                --set api.image.repository="${params.BACKEND_IMAGE_REPO}" \
                                --set eventsJob.image.tag="${params.DB_INIT_VERSION_TAG}" \
                                --set eventsJob.image.repository="${params.DB_INIT_IMAGE_REPO}"
                                """
                            } catch (Exception e) {
                                echo "Failed to install events-app: ${e.getMessage()}"
                                sh '${BIN_PATH}/helm uninstall events-app'
                                error "Failed to deploy events-app, rolling back"
                            }
                        } else {
                            sh """
                            export MARIADB_ROOT_PASS=\$(${BIN_PATH}/kubectl get secret --namespace "default" events-app-mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 -d)
                            ${BIN_PATH}/helm upgrade events-app . -f values.yaml \
                            --set website.image.tag="${params.FRONTEND_VERSION_TAG}" \
                            --set website.image.repository="${params.FRONTEND_IMAGE_REPO}" \
                            --set api.image.tag="${params.BACKEND_VERSION_TAG}" \
                            --set api.image.repository="${params.BACKEND_IMAGE_REPO}" \
                            --set eventsJob.image.tag="${params.DB_INIT_VERSION_TAG}" \
                            --set eventsJob.image.repository="${params.DB_INIT_IMAGE_REPO}" \
                            --set mariadb.auth.rootPassword="\$MARIADB_ROOT_PASS"
                            """
                        }
                        sh '''
                        export SERVICE_IP=$(kubectl get svc --namespace default events-app-website-svc --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
                        echo http://$SERVICE_IP:80
                        '''
                    }
                }
            }
        }
    }
}
