pipeline {
  agent any
  options { timestamps() }

  environment {
    IMAGE_NAME = 'abrahamyuxin/express-sample'
  }

  stages {

    stage('Checkout') {
      steps {
        deleteDir()
        checkout scm
        // Sanity check: list files so we see package.json in logs
        sh 'ls -la && echo "----" && head -n 20 package.json || true'
      }
    }

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

          # Create a throwaway Node container
          cid=$(docker create node:16-bullseye bash -lc "sleep 9999")
          trap "docker rm -f $cid >/dev/null 2>&1 || true" EXIT

          # Copy the Jenkins workspace into the container
          docker cp "$WORKSPACE"/. "$cid":/workspace

          # Run install & test inside container
          docker exec -w /workspace "$cid" bash -lc '
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
      when { expression { return false } } // <-- remove this once you add a valid snyk-token
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            set -eux

            cid=$(docker create -e SNYK_TOKEN="$SNYK_TOKEN" node:16-bullseye bash -lc "sleep 9999")
            trap "docker rm -f $cid >/dev/null 2>&1 || true" EXIT

            docker cp "$WORKSPACE"/. "$cid":/workspace

            docker exec -w /workspace "$cid" bash -lc '
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
