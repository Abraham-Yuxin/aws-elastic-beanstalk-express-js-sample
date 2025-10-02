pipeline {
  agent any
  options { timestamps() }

  environment {
    IMAGE_NAME = 'abrahamyuxin/express-sample'
  }

  stages {
    stage('Verify Docker (TLS to DinD)') {
      steps {
        sh '''
          set -eux
          getent hosts docker
          docker version
        '''
      }
    }

    stage('Install & Test in Node 16 container') {
      steps {
        sh '''
          set -eux
          # Mount the Jenkins workspace (shared volume) into the Node container
          docker run --rm \
            -v "$WORKSPACE":/workspace \
            -w /workspace \
            node:16-bullseye \
            bash -lc '
              node -v &&
              if [ -f package-lock.json ]; then npm ci; else npm install; fi &&
              npm test
            '
        '''
      }
    }

    stage('Docker Build & Tag') {
      steps {
        sh '''
          set -eux
          docker build -t $IMAGE_NAME:${BUILD_NUMBER} .
          docker tag   $IMAGE_NAME:${BUILD_NUMBER} $IMAGE_NAME:latest
        '''
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            set -eux
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker push $IMAGE_NAME:${BUILD_NUMBER}
            docker push $IMAGE_NAME:latest
          '''
        }
      }
    }

    stage('Dependency Security Scan (Snyk)') {
      when { expression { return false } } // <-- remove this line after you add Snyk token/step
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            set -eux
            docker run --rm \
              -e SNYK_TOKEN="$SNYK_TOKEN" \
              -v "$WORKSPACE":/workspace \
              -w /workspace \
              node:16-bullseye \
              bash -lc '
                npm i -g snyk &&
                snyk auth "$SNYK_TOKEN" &&
                snyk test --severity-threshold=high
              '
          '''
        }
      }
    }
  }
}
