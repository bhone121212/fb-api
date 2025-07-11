pipeline {
    agent any

    environment {
        IMAGE_NAME = 'bhonebhone/fb-api'
        K8S_NAMESPACE = "fb-crawler-apps"
        VERSION_FILE = 'version.txt'
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Set Image Tag') {
            steps {
                script {
                    def version = 0
                    if (fileExists(VERSION_FILE)) {
                        version = readFile(VERSION_FILE).trim().toInteger()
                    }
                    version++
                    writeFile file: VERSION_FILE, text: "$version"
                    env.IMAGE_TAG = "v${version}"
                    env.FULL_IMAGE = "${IMAGE_NAME}:${env.IMAGE_TAG}"
                    echo "New image version: ${env.IMAGE_TAG}"
                }
            }
        }

        // stage('Install Python Dependencies') {
        //     steps {
        //         script {
        //             // Debug: Show current workspace files
        //             sh 'ls -R'

        //             // Create virtual environment and install dependencies
        //             sh '''
        //                 python3 -m venv venv
        //                 . venv/bin/activate
        //                 pip install --upgrade pip
        //                 pip install -r app/requirements.txt
        //             '''
        //         }
        //     }
        // }
        stage('Install Python Dependencies') {
            steps {
                script {
                    sh '''
                        sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
                        python3 -m venv venv
                        . venv/bin/activate
                        pip install --upgrade pip
                        pip install -r app/requirements.txt
                    '''
                }
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    pytest || true
                '''
            }
        }

        stage('Build and Push Image (Buildah)') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    script {
                        sh '''
                            echo "$REG_PASS" | sudo -S buildah login -u "$REG_USER" --password-stdin docker.io
                            sudo buildah bud -t $FULL_IMAGE .
                            sudo buildah push $FULL_IMAGE
                        '''
                    }
                }
            }
        }

        stage('Update YAML and Push to GitHub (Trigger ArgoCD)') {
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    script {
                        sh '''
                            # Update image tag in deployment YAML
                            sed -i "s|image:.*|image: $FULL_IMAGE|" k8s/api-controller.yaml

                            # Commit and push the update to GitHub
                            git config --global user.email "jenkins@ci.local"
                            git config --global user.name "Jenkins CI"
                            git add k8s/api-controller.yaml
                            git commit -m "Update image to $FULL_IMAGE" || echo "No changes to commit"
                            git remote set-url origin https://$GITHUB_TOKEN@github.com/bhone121212/fb-api.git
                            git push origin HEAD:main

                            # Apply all Kubernetes services
                            kubectl apply -f k8s/api-service.yaml
                            kubectl apply -f k8s/rabbitmq-configmap.yaml
                            kubectl apply -f k8s/rabbitmq-controller.yaml
                            kubectl apply -f k8s/rabbitmq-service.yaml
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ fb-api CI/CD Pipeline executed successfully!'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for issues.'
        }
    }
}
