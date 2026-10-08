pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Format Check') {
            steps {
                bat '''
                    cd terraform
                    terraform fmt -check
                '''
            }
        }

        stage('Terraform Validate') {
            steps {
                bat '''
                    cd terraform
                    terraform validate
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                bat '''
                    cd terraform
                    terraform plan
                '''
            }
        }
    }
}