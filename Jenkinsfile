// Jenkinsfile (Declarative Pipeline)
// - Build/Test & Snyk Scan run in a Node 16 container (stage-level agent).
// - Docker build/push runs on Jenkins controller using docker CLI over TLS to dind.
// - TLS/HTTPS to Docker daemon is controlled by DOCKER_HOST/DOCKER_CERT_PATH/DOCKER_TLS_VERIFY.
//
// Make sure your repo has a Dockerfile at the root (or adjust the build context accordingly).

pipeline {
  agent none

  environment {
    // Image name (repo) to push to, e.g., "yourname/yourapp"
    IMAGE_NAME = 'yourdockerhubuser/your-app'

    // Remote Docker daemon (dind) over TLS (HTTPS)
    DOCKER_HOST       = 'tcp://docker:2376'
    DOCKER_CERT_PATH  = '/certs/client'
    DOCKER_TLS_VERIFY = '1'
  }

  options {
    timestamps()
    ansiColor('xterm')
  }

  stages {
    stage('Checkout') {
      agent any
      steps {
        checkout scm
      }
    }

    stage('Install & Test (Node 16)') {
      agent {
        docker {
          image 'node:16-bullseye'
          // root user to avoid perms issues when writing node_modules
          args '-u root:root'
        }
      }
      steps {
        sh 'node -v'
        // Install dependencies (lockfile-aware if you prefer npm ci)
        sh '''
          if [ -f package-lock.json ]; then
            npm ci
          else
            npm install
          fi
        '''
        // Run tests (won't fail if no test script is present)
        sh 'npm test --if-present'
      }
    }

    stage('Dependency Security Scan (Snyk)') {
      agent {
        docker {
          image 'node:16-bullseye'
          args '-u root:root'
        }
      }
      environment {
        SNYK_TOKEN = credentials('snyk-token')
      }
      steps {
        sh '''
          npm install -g snyk
          snyk auth "$SNYK_TOKEN"
          # Fail the build if any High/Critical issues are detected.
          snyk test --severity-threshold=high
        '''
      }
    }

    stage('Docker Build & Push (to registry via dind)') {
      agent any  // runs on Jenkins controller where docker CLI is installed
      environment {
        // Use short SHA for tag; fallback to `latest` on non-Git contexts
        SHORT_SHA = "${env.GIT_COMMIT ?: 'manual'}"
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                         usernameVariable: 'DOCKERHUB_USERNAME',
                                         passwordVariable: 'DOCKERHUB_TOKEN')]) {
          sh '''
            set -eux
            docker version   # should show Server: ... (dind) thanks to TLS envs

            # Tag: repo:shortsha (7)
            TAG=${SHORT_SHA:0:7}
            IMAGE="${IMAGE_NAME}:${TAG}"

            echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

            # Build and push
            docker build -t "$IMAGE" .
            docker push "$IMAGE"

            # Also push/update a "latest" tag (optional)
            docker tag "$IMAGE" "${IMAGE_NAME}:latest"
            docker push "${IMAGE_NAME}:latest"

            # Output for traceability
            echo "$IMAGE" > pushed-image.txt
          '''
        }
      }
      post {
        always {
          archiveArtifacts artifacts: 'pushed-image.txt', onlyIfSuccessful: false
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline completed successfully."
    }
    failure {
      echo "Pipeline failed. Check logs (tests or Snyk may have blocked the build)."
    }
  }
}
