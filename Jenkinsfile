pipeline {
    agent any

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region for all resources')
        string(name: 'AWS_CREDENTIALS_ID', defaultValue: 'aws-credentials', description: 'The ID of a Credentials resource for AWS (expecting kind AWS Credentials)')
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
                withCredentials([aws(credentialsId: '$AWS_CREDENTIALS_ID', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
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
                    echo "Installing eksctl"
                    sh 'curl -sLO "https://get.helm.sh/helm-v3.18.3-linux-amd64.tar.gz"'
                    sh 'tar -xzf helm-v3.18.3-linux-amd64.tar.gz -C /tmp && rm helm-v3.18.3-linux-amd64.tar.gz'
                    sh 'mv /tmp/helm ~/.local/bin/helm'                    
                    echo "Getting helm version"
                    sh '${BIN_PATH}/helm --version'
                }
            }
        }

        stage('Clone the devops repo') {
            steps {
                echo 'Cloning devops project repository'
                git branch: 'main',
                    url: 'https://github.com/AWS-Engagement-Ready-Final-Project/aws-final.git'
                echo 'Was repo cloned?'
                sh 'ls -a'
            }
        }
        
        stage('Check for backend changes') {
            steps {
                script {
                    echo 'Checking for changes in backend directory'
                    def changes = sh(script: "git diff --name-only HEAD~1 HEAD | grep '^backend/' || true", returnStdout: true).trim()
                    if (changes) {
                        echo "Changes detected:\n${changes}"
                        env.BUILD_BACKEND_IMAGE = 'true'
                    } else {
                        echo "No changes in backend directory."
                        env.BUILD_BACKEND_IMAGE = 'false'
                    }
                }
            }
        }
        
        
        stage('Determine new backend image tag') {
            steps {
                script {
                    def backendImage = 'wburgis/devops-er-backend'
                    def tagsJson = sh(
                        script: "curl -s https://hub.docker.com/v2/repositories/${backendImage}/tags?page_size=100",
                        returnStdout: true
                    ).trim()
        
                    def tags = readJSON text: tagsJson
                    def versionTags = tags.results.collect { it.name }
                    
                    echo "Version tags: ${versionTags}"

                    def newTag = '1.0'
                    if (versionTags) {
                        def maxMajor = 0
                        def maxMinor = 0

                        for (tag in versionTags) {
                            def parts = tag.tokenize('.')
                            def major = parts[0].toInteger()
                            def minor = parts[1].toInteger()

                            if (major > maxMajor || (major == maxMajor && minor > maxMinor)) {
                                maxMajor = major
                                maxMinor = minor
                            }
                        }

                        if (env.BUILD_BACKEND_IMAGE == 'true') {
                            newTag = "${maxMajor}.${maxMinor + 1}"
                        } else {
                            newTag = "${maxMajor}.${maxMinor}"
                        }
                    }

                    env.BACKEND_IMAGE_TAG = newTag
                    echo "New Docker image tag: ${env.BACKEND_IMAGE_TAG}"
                }
            }
        }

        stage('Build backend Docker image') {
            when {
                expression { env.BUILD_BACKEND_IMAGE == 'true' }
            }
            steps {
                script {
                    echo 'Building backend Docker image'
                    dir('backend') {
                        def backendImageName = 'wburgis/devops-er-backend'
                        sh "docker build -t ${backendImageName}:${env.BACKEND_IMAGE_TAG} ."
                    }
                }
            }
        }
        
        stage('Push backend Docker image') {
            when {
                expression { env.BUILD_BACKEND_IMAGE == 'true' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: '5cd81998-a923-4dc4-8b0c-a3d5239f9661', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push wburgis/devops-er-backend:${BACKEND_IMAGE_TAG}
                    '''
                }
            }
        }
        
        stage('Check for frontend changes') {
            steps {
                script {
                    echo 'Checking for changes in frontend directory'
                    def changes = sh(script: "git diff --name-only HEAD~1 HEAD | grep '^frontend/' || true", returnStdout: true).trim()
                    if (changes) {
                        echo "Changes detected:\n${changes}"
                        env.BUILD_FRONTEND_IMAGE = 'true'
                    } else {
                        echo "No changes in frontend directory."
                        env.BUILD_FRONTEND_IMAGE = 'false'
                    }
                }
            }
        }
        
        
        stage('Determine new frontend image tag') {
            steps {
                script {
                    def frontendImage = 'wburgis/devops-er-frontend'
                    def tagsJson = sh(
                        script: "curl -s https://hub.docker.com/v2/repositories/${frontendImage}/tags?page_size=100",
                        returnStdout: true
                    ).trim()
        
                    def tags = readJSON text: tagsJson
                    def versionTags = tags.results.collect { it.name }
                    
                    echo "Version tags: ${versionTags}"

                    def newTag = '1.0'
                    if (versionTags) {
                        def maxMajor = 0
                        def maxMinor = 0

                        for (tag in versionTags) {
                            def parts = tag.tokenize('.')
                            def major = parts[0].toInteger()
                            def minor = parts[1].toInteger()

                            if (major > maxMajor || (major == maxMajor && minor > maxMinor)) {
                                maxMajor = major
                                maxMinor = minor
                            }
                        }

                        if (env.BUILD_FRONTEND_IMAGE == 'true') {
                            newTag = "${maxMajor}.${maxMinor + 1}"
                        } else {
                            newTag = "${maxMajor}.${maxMinor}"
                        }
                    }

                    env.FRONTEND_IMAGE_TAG = newTag
                    echo "New Docker image tag: ${env.FRONTEND_IMAGE_TAG}"
                }
            }
        }

        stage('Build frontend Docker image') {
            when {
                expression { env.BUILD_FRONTEND_IMAGE == 'true' }
            }
            steps {
                script {
                    echo 'Building frontend Docker image'
                    dir('frontend') {
                        def frontendImageName = 'wburgis/devops-er-frontend'
                        sh "docker build -t ${frontendImageName}:${env.FRONTEND_IMAGE_TAG} ."
                    }
                }
            }
        }
        
        stage('Push frontend Docker image') {
            when {
                expression { env.BUILD_FRONTEND_IMAGE == 'true' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: '5cd81998-a923-4dc4-8b0c-a3d5239f9661', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push wburgis/devops-er-frontend:${FRONTEND_IMAGE_TAG}
                    '''
                }
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
                sh '${BIN_PATH}/eksctl create cluster -f kubernetes-config/cluster.yaml'       
            }
        }

        stage('Deploy backend to EKS') {
            steps {
                script {
                    echo "Deploying backend to EKS"
            
                    // Update kubeconfig to interact with the EKS cluster
                    sh '''
                        aws eks update-kubeconfig --region $AWS_REGION --name aws-final-capstone
                    '''

                    def currentImage = sh(
                        script: """
                            selector=\$(${BIN_PATH}/kubectl get service events-api-svc -o=jsonpath='{.spec.selector.ver}')
                            pod=\$(${BIN_PATH}/kubectl get pods -l app=events-api,ver=\$selector -o=jsonpath='{.items[0].metadata.name}')
                            ${BIN_PATH}/kubectl get pod \$pod -o=jsonpath='{.spec.containers[0].image}'
                        """,
                        returnStdout: true
                    ).trim()

                    def newImage = "wburgis/devops-er-backend:${env.BACKEND_IMAGE_TAG}"
                    def newVersion = env.BACKEND_IMAGE_TAG.replace('.', '-')

                    if (currentImage != newImage) {
                        echo "New image detected: ${newImage}. Updating deployment..."

                        // Create new deployment for new version
                        sh "sed 's|{{VERSION}}|${newVersion}|g; s|{{IMAGE}}|${newImage}|g' kubernetes-config/api-deployment-template.yaml > kubernetes-config/api-deployment-${newVersion}.yaml"
                        sh "${BIN_PATH}/kubectl apply -f kubernetes-config/api-deployment-${newVersion}.yaml"

                        // Update service with new version
                        sh """
                            ${BIN_PATH}/kubectl patch service events-api-svc \
                            -p '{"spec": {"selector": {"app": "events-api", "ver": "${newVersion}"}}}'
                        """
                    } else {
                        echo "Current frontend image: ${newImage} is up to date"
                    }
                }
            }
        }

        stage('Deploy frontend to EKS') {
            steps {
                script {
                    echo "Deploying frontend to EKS"
            
                    // Update kubeconfig to interact with the EKS cluster
                    sh '''
                        aws eks update-kubeconfig --region $AWS_REGION --name aws-final-capstone
                    '''
            
                    def currentImage = sh(
                        script: """
                            selector=\$(${BIN_PATH}/kubectl get service events-web-svc -o=jsonpath='{.spec.selector.ver}')
                            pod=\$(${BIN_PATH}/kubectl get pods -l app=events-web,ver=\$selector -o=jsonpath='{.items[0].metadata.name}')
                            ${BIN_PATH}/kubectl get pod \$pod -o=jsonpath='{.spec.containers[0].image}'
                        """,
                        returnStdout: true
                    ).trim()
 

                    def newImage = "wburgis/devops-er-frontend:${env.FRONTEND_IMAGE_TAG}"
                    def newVersion = env.FRONTEND_IMAGE_TAG.replace('.', '-')

                    echo "Current image: ${currentImage}"
                    echo "New image: ${newImage}"

                    if (currentImage != newImage) {
                        echo "New image detected: ${newImage}. Updating deployment..."

                        // Create new deployment for new version
                        sh "sed 's|{{VERSION}}|${newVersion}|g; s|{{IMAGE}}|${newImage}|g' kubernetes-config/web-deployment-template.yaml > kubernetes-config/web-deployment-${newVersion}.yaml"
                        sh "${BIN_PATH}/kubectl apply -f kubernetes-config/web-deployment-${newVersion}.yaml"

                        // Update service with new version
                        sh """
                            ${BIN_PATH}/kubectl patch service events-web-svc \
                            -p '{"spec": {"selector": {"app": "events-web", "ver": "${newVersion}"}}}'
                        """
                    } else {
                        echo "Current frontend image: ${newImage} is up to date"
                    }
                }
            }
        }
    }
}

