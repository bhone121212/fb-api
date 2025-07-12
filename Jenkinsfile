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

         stage('Validate Branch') {
            when {
                expression {
                    return env.BRANCH_NAME == 'main'
                }
            }
            steps {
                echo "✅ Proceeding with build: Branch is 'main'"
            }
        }

        stage('Skipped for other branches') {
            when {
                expression {
                    return env.BRANCH_NAME != 'main'
                }
            }
            steps {
                echo "🚫 Skipping build: Branch is '${env.BRANCH_NAME}', only 'main' is allowed"
                script {
                    currentBuild.result = 'NOT_BUILT'
                    error("Not main branch. Skipping pipeline.")
                }
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

        // stage('Clean Up Old Images') {
        //     steps {
        //         script {
        //             sh '''
        //                 echo "🧹 Cleaning up old images for $IMAGE_NAME, keeping only: $FULL_IMAGE"
        //                 KEEP_ID=$(buildah images --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep "$FULL_IMAGE" | awk '{print $1}')
        //                 echo "🆕 Keeping image ID: $KEEP_ID"

        //                 buildah images --format "{{.ID}} {{.Repository}}" | grep "$IMAGE_NAME" | awk '{print $1}' | while read imgid; do
        //                     if [ "$imgid" != "$KEEP_ID" ]; then
        //                         echo "🗑️ Deleting image $imgid"
        //                         buildah rmi -f "$imgid" || true
        //                     fi
        //                 done
        //             '''
        //         }
        //     }
        // }
    //     stage('Clean Up Old Images') {
    //     steps {
    //         script {
    //             sh '''
    //                 echo "🧹 Cleaning up old images for $IMAGE_NAME, keeping only the latest 5"

    //                 # Get latest 5 image IDs sorted by creation time (desc)
    //                 KEEP_IDS=$(buildah images --format "{{.CreatedAt}} {{.ID}} {{.Repository}}:{{.Tag}}" \
    //                     | grep "$IMAGE_NAME" \
    //                     | sort -r \
    //                     | head -n 5 \
    //                     | awk '{print $2}')

    //                 echo "🆕 Keeping these image IDs:"
    //                 echo "$KEEP_IDS"

    //                 # Get all image IDs of this repo
    //                 ALL_IDS=$(buildah images --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep "$IMAGE_NAME" | awk '{print $1}')

    //                 for id in $ALL_IDS; do
    //                     if ! echo "$KEEP_IDS" | grep -q "$id"; then
    //                         echo "🗑️ Deleting old image: $id"
    //                         buildah rmi -f "$id" || true
    //                     fi
    //                 done
    //             '''
    //         }
    //     }
    // }
    stage('Clean Up Old Images') {
    steps {
        script {
            sh '''
                echo "🧹 Cleaning up old images for $IMAGE_NAME, keeping only the latest 5"

                # Get latest 5 image IDs sorted by creation time (desc)
                KEEP_IDS=$(buildah images --format "{{.CreatedAt}} {{.ID}} {{.Repository}}:{{.Tag}}" \
                    | grep "$IMAGE_NAME" \
                    | sort -r \
                    | head -n 5 \
                    | awk '{print $2}')

                echo "🆕 Keeping these image IDs:"
                echo "$KEEP_IDS"

                # Get all image IDs of this repo
                ALL_IDS=$(buildah images --format "{{.ID}} {{.Repository}}" | grep "$IMAGE_NAME" | awk '{print $1}')

                for id in $ALL_IDS; do
                    if ! echo "$KEEP_IDS" | grep -q "$id"; then
                        echo "🗑️ Deleting old image: $id"
                        buildah rmi -f "$id" || true
                    fi
                done
            '''
        }
    }
}




        stage('Update YAML and Push to GitHub (Trigger ArgoCD)') {
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    script {
                        sh '''
                            echo "🔄 Updating Kubernetes YAML with image: $FULL_IMAGE"

                            # Update image tag
                            sed -i "s|image:.*|image: $FULL_IMAGE|" k8s/api-controller.yaml
                            sed -i "s|image:.*|image: $FULL_IMAGE|" k8s/api-service.yaml

                            # Ensure all YAML files have correct namespace
                            for file in k8s/*.yaml; do
                                sed -i "s|^namespace:.*|namespace: $K8S_NAMESPACE|" "$file"
                            done

                            git config --global user.email "jenkins@ci.local"
                            git config --global user.name "Jenkins CI"

                            if ! git diff --quiet k8s/; then
                                git add k8s/
                                git commit -m "Update image to $FULL_IMAGE"
                                git remote set-url origin https://$GITHUB_TOKEN@github.com/bhone121212/fb-api.git
                                git push origin HEAD:main
                                echo "✅ GitHub pushed with new image tag"
                            else
                                echo "⚠️ No changes in image tag. Skipping GitHub push."
                            fi


                            echo "🚀 Applying Kubernetes resources to $K8S_NAMESPACE"
                            kubectl apply -n $K8S_NAMESPACE -f k8s/api-controller.yaml
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
