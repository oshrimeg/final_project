pipeline {
    agent any

    stages {
        stage('Clone') {
            steps {
                git url: 'https://github.com/oshrimeg/k8s_contacts.git', branch: 'main'
            }
        }

        stage('Deploy to K8s') {
            steps {
                script {
                    // Inject AWS credentials securely using Jenkins' withCredentials block
                    withCredentials([usernamePassword(credentialsId: 'aws_credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        // Run AWS CLI command to update kubeconfig for the EKS cluster
                        sh 'aws eks --region us-east-1 update-kubeconfig --name my-terra-cluster'
                        
                        // Apply Kubernetes resources (ConfigMap, Secret, Deployment, Service)
                        sh 'kubectl apply -f config-map-db.yaml'
                        sh 'kubectl apply -f secret-mysql.yaml'
                        sh 'kubectl apply -f flask-app-dplm-svc.yaml'
                        sh 'kubectl apply -f mysql-deployment.yaml'
                        sh 'kubectl apply -f mysql-service.yaml'
                    }
                }
            }
        }
    }
}