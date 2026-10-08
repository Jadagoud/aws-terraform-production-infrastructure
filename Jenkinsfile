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

stage('Terraform Init') {
    steps {
        withCredentials([
            usernamePassword(
                credentialsId: 'aws-terraform',
                usernameVariable: 'AWS_ACCESS_KEY_ID',
                passwordVariable: 'AWS_SECRET_ACCESS_KEY'
            )
        ]) {
            bat '''
                set AWS_DEFAULT_REGION=eu-north-1
                cd terraform
                terraform init
            '''
        }
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
        withCredentials([
            usernamePassword(
                credentialsId: 'aws-terraform',
                usernameVariable: 'AWS_ACCESS_KEY_ID',
                passwordVariable: 'AWS_SECRET_ACCESS_KEY'
            )
        ]) {
            bat '''
                set AWS_DEFAULT_REGION=eu-north-1
                cd terraform
                terraform plan
            '''
        }
    }
}