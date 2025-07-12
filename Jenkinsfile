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
                    echo "📦 New image version: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Run Tests') {
            steps {
                echo '🔎 Skipping tests - handled in container if needed'
                // Uncomment to run actual tests:
                // sh '. venv/bin/activate && pytest || true'
            }
        }

        stage('Build and Push Image (Buildah)') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    script {
                        sh 'echo "$REG_PASS" | sudo -S buildah login -u "$REG_USER" --password-stdin docker.io'
                        sh "sudo buildah bud -t $FULL_IMAGE ."
                        sh "sudo buildah push $FULL_IMAGE"
                    }
                }
            }
        }

        stage('Update YAML and Push to GitHub (Trigger ArgoCD)') {
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    script {
                        sh '''
                            echo "🔄 Updating Kubernetes YAML with image: $FULL_IMAGE"

                            sed -i "s|image:.*|image: $FULL_IMAGE|" k8s/api-controller.yaml
                            sed -i "s|image:.*|image: $FULL_IMAGE|" k8s/api-service.yaml

                            git config --global user.email "jenkins@ci.local"
                            git config --global user.name "Jenkins CI"

                            if ! git diff --quiet k8s/api-controller.yaml k8s/api-service.yaml; then
                                git add k8s/api-controller.yaml k8s/api-service.yaml
                                git commit -m "Update image to $FULL_IMAGE"
                                git remote set-url origin https://$GITHUB_TOKEN@github.com/bhone121212/fb-api.git
                                git push origin HEAD:main
                                echo "✅ GitHub pushed with new image tag"
                            else
                                echo "⚠️ No changes in image tag. Skipping GitHub push."
                            fi

                            echo "🚀 Applying Kubernetes resources to $K8S_NAMESPACE"
                            kubectl apply -n $K8S_NAMESPACE -f k8s/api-service.yaml
                            kubectl apply -n $K8S_NAMESPACE -f k8s/rabbitmq-configmap.yaml
                            kubectl apply -n $K8S_NAMESPACE -f k8s/rabbitmq-controller.yaml
                            kubectl apply -n $K8S_NAMESPACE -f k8s/rabbitmq-service.yaml
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
