pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-terraform')
        AWS_SECRET_ACCESS_KEY = credentials('aws-terraform_PSW')
        AWS_DEFAULT_REGION    = 'eu-north-1'
    }

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

  stage('Terraform Init') {
    steps {
        bat '''
            cd terraform
            terraform init
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