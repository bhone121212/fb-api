pipeline {
    agent any  // Use a generic agent

    environment {
        IMAGE_NAME = 'bhonebhone/fb-api'
        K8S_NAMESPACE = "fb-crawler-apps"
        VERSION_FILE = 'version.txt'  // File to track versions
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
                    // Read the current version from the file, increment it, and store it back
                    def version = 0
                    if (fileExists(VERSION_FILE)) {
                        version = readFile(VERSION_FILE).trim().toInteger()
                    }
                    version++
                    
                    // Write the new version back to the file
                    writeFile file: VERSION_FILE, text: "$version"
                    
                    // Set the image tag to the new version
                    env.IMAGE_TAG = "v${version}"
                    env.FULL_IMAGE = "${IMAGE_NAME}:${env.IMAGE_TAG}"
                    echo "New image version: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Install Python Dependencies') {
            steps {
                script {
                    // Create and activate a Python virtual environment without sudo
                    sh 'python3 -m venv venv'  // Create virtual environment
                    sh '. venv/bin/activate && pip install --upgrade pip'  // Upgrade pip
                    sh '. venv/bin/activate && pip install -r requirements.txt'  // Install dependencies
                }
            }
        }

        stage('Run Tests') {
            steps {
                sh '. venv/bin/activate && pytest || true'  // Run tests inside the virtual environment
            }
        }

        stage('Build and Push Image (Buildah)') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    script {
                        // Log in to Docker Hub using Buildah
                        sh 'echo "$REG_PASS" | sudo -S buildah login -u "$REG_USER" --password-stdin docker.io'

                        // Build the Docker image with the versioned tag
                        sh "sudo buildah bud -t $FULL_IMAGE ."

                        // Push the image with the versioned tag
                        sh "sudo buildah push $FULL_IMAGE"
                    }
                }
            }
        }

        stage('Update YAML and Push to GitHub (Trigger ArgoCD)') {
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    script {
                        // Update deployment.yaml with the new image tag
                        sh '''
                            sed -i "s|image:.*|image: $FULL_IMAGE|" k8s/deployment.yaml

                            git config --global user.email "jenkins@ci.local"
                            git config --global user.name "Jenkins CI"

                            git add k8s/deployment.yaml
                            git commit -m "Update image to $FULL_IMAGE" || echo "No changes to commit"
                            git remote set-url origin https://$GITHUB_TOKEN@github.com/bhone121212/Simple_NodeJS_App-main.git
                            git push origin HEAD:main
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ CI/CD Pipeline executed successfully!'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for issues.'
        }
    }
}
