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
                    ),
                    string(
                        credentialsId: 'rds-password',
                        variable: 'RDS_PASSWORD'
                    )
                ]) {
                    bat '''
                        set AWS_DEFAULT_REGION=eu-north-1
                        set TF_VAR_rds_password=%RDS_PASSWORD%
                        cd terraform
                        terraform plan
                    '''
                }
            }
        }

        stage('Build Backend Image') {
            steps {
                bat 'docker build -t devops-backend:latest ./backend'
            }
        }

        stage('Build Frontend Image') {
            steps {
                bat 'docker build -t devops-frontend:latest ./frontend'
            }
        }

        stage('Push Images to ECR') {
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

                        aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin 451782721795.dkr.ecr.eu-north-1.amazonaws.com

                        docker tag devops-backend:latest 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-backend:latest
                        docker tag devops-frontend:latest 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-frontend:latest

                        docker push 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-backend:latest
                        docker push 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-frontend:latest
                    '''
                }
            }
        }

        stage('Test SSM Deployment Access') {
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
                        aws ssm send-command ^
                            --instance-ids i-09a4bbf8149dc3706 ^
                            --document-name AWS-RunShellScript ^
                            --parameters commands="echo SSM_PERMISSION_TEST_OK" ^
                            --query "Command.CommandId" ^
                            --output text
                    '''
                }
            }
        }

    }
}
