pipeline {
  agent none

  environment {
    IMAGE_NAME        = 'abrahamyuxin/express-sample'
    DOCKER_HOST       = 'tcp://docker:2376'
    DOCKER_CERT_PATH  = '/certs/client'
    DOCKER_TLS_VERIFY = '1'
  }

  options {
    timestamps()
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
          args '-u root:root'
        }
      }
      steps {
        sh 'node -v'
        sh '''
          if [ -f package-lock.json ]; then
            npm ci
          else
            npm install
          fi
        '''
        // Run tests if present (won’t fail if script missing)
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
          set -eux
          npm install -g snyk
          snyk auth "$SNYK_TOKEN"
          # Fail the build if High/Critical issues are found
          snyk test --severity-threshold=high
        '''
      }
    }

    stage('Docker Build & Push (TLS to dind)') {
      agent any
      environment {
        SHORT_SHA = "${env.GIT_COMMIT ?: 'manual'}"
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                         usernameVariable: 'DOCKERHUB_USERNAME',
                                         passwordVariable: 'DOCKERHUB_TOKEN')]) {
          sh '''
            set -eux
            docker version  # should show Server: ... (dind) via TLS

            TAG=${SHORT_SHA:0:7}
            IMAGE="${IMAGE_NAME}:${TAG}"

            echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

            docker build -t "$IMAGE" .
            docker push "$IMAGE"

            docker tag "$IMAGE" "${IMAGE_NAME}:latest"
            docker push "${IMAGE_NAME}:latest"

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
    success { echo 'Pipeline completed successfully.' }
    failure { echo 'Pipeline failed (tests or Snyk may have blocked the build).' }
  }
}
