pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'DEPLOY_BACKEND',
            defaultValue: false,
            description: 'Deploy the backend to production through SSM. Enable only for an approved deployment.'
        )
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
])                {
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
docker tag devops-backend:latest 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-backend:%BUILD_NUMBER%
docker tag devops-frontend:latest 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-frontend:latest

docker push 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-backend:latest
docker push 451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-backend:%BUILD_NUMBER%
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
                    powershell '''
                        $ErrorActionPreference = "Stop"
                        $env:AWS_DEFAULT_REGION = "eu-north-1"
                        $instanceId = "i-09a4bbf8149dc3706"

                        $commandId = aws ssm send-command `
                            --instance-ids $instanceId `
                            --document-name AWS-RunShellScript `
                            --parameters 'commands=["echo SSM_PERMISSION_TEST_OK"]' `
                            --query "Command.CommandId" `
                            --output text

                        if ($LASTEXITCODE -ne 0 -or
                            $commandId -notmatch '^[0-9a-fA-F-]{36}$') {
                            throw "Failed to submit SSM access test."
                        }

                        Write-Host "SSM test command submitted: $commandId"
                        $deadline = (Get-Date).AddMinutes(3)
                        $status = ""

                        while ((Get-Date) -lt $deadline) {
                            Start-Sleep -Seconds 5

                            $result = aws ssm get-command-invocation `
                                --command-id $commandId `
                                --instance-id $instanceId `
                                --query "[Status,StandardOutputContent,StandardErrorContent]" `
                                --output json 2>$null

                            if ($LASTEXITCODE -ne 0) {
                                continue
                            }

                            $invocation = $result | ConvertFrom-Json
                            $status = "$($invocation[0])".Trim()

                            if ($status -in @(
                                "Success", "Failed", "Cancelled", "TimedOut",
                                "Undeliverable", "Terminated"
                            )) {
                                break
                            }
                        }

                        if ($status -ne "Success") {
                            throw "SSM access test did not succeed. Final status: $status"
                        }

                        $output = "$($invocation[1])"
                        if ($output -notmatch "SSM_PERMISSION_TEST_OK") {
                            throw "SSM command succeeded but the expected output was not found."
                        }

                        Write-Host "SSM access test succeeded."
                    '''
                }
            }
        }



        stage('Deploy Backend via SSM') {
            when {
                expression { params.DEPLOY_BACKEND == true }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-terraform',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    powershell '''
                        $ErrorActionPreference = "Stop"
                        $env:AWS_DEFAULT_REGION = "eu-north-1"

                        $instanceId = "i-09a4bbf8149dc3706"
                        $bucket = "devops-backend-deploy-451782721795"
                        $registry = "451782721795.dkr.ecr.eu-north-1.amazonaws.com"
                        $repository = "devops-backend"

                        # Resolve the current image to an immutable digest.
                        $buildNumber = $env:BUILD_NUMBER

                        if ($buildNumber -notmatch '^[0-9]+$') {
                            throw "Invalid Jenkins build number."
                        }

                        $digest = aws ecr describe-images `
                            --repository-name $repository `
                            --image-ids "imageTag=$buildNumber" `
                            --query "imageDetails[0].imageDigest" `
                            --output text

                        if ($LASTEXITCODE -ne 0 -or
                            $digest -notmatch '^sha256:[a-f0-9]{64}$') {
                            throw "Could not resolve the backend image for build $buildNumber."
                        }

                        $image = "$registry/$repository@$digest"

                                                # Use a unique artifact key for each Jenkins build.
                        $scriptPath = Join-Path $env:WORKSPACE "scripts/deploy-backend.sh"
                        if (-not (Test-Path $scriptPath -PathType Leaf)) {
                            throw "Deployment script not found in workspace."
                        }

                        $checksum = (Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToLowerInvariant()

                        $s3Key = "deploy-backend/$buildNumber/deploy-backend.sh"
                        $s3Uri = "s3://$bucket/$s3Key"

                        Write-Host "Uploading deployment artifact to S3..."
                        aws s3 cp $scriptPath $s3Uri --only-show-errors
                        if ($LASTEXITCODE -ne 0) {
                            throw "Deployment artifact upload to S3 failed."
                        }

                        # Only short, validated values are sent through SSM.
                        $remoteCommands = @(
                            'set -eu',
                            'umask 077',
                            'install -d -o root -g root -m 700 /opt/devops-deploy',
                            'tmp=$(mktemp /opt/devops-deploy/deploy-backend.XXXXXX)',
                            'trap ''rm -f "$tmp"'' EXIT',
                            "aws s3 cp '$s3Uri' `"`$tmp`" --only-show-errors",
                            "printf '%s  %s\n' '$checksum' `"`$tmp`" | sha256sum -c -",
                            'chown root:root "$tmp"',
                            'chmod 700 "$tmp"',
                            'mv -f "$tmp" /opt/devops-deploy/deploy-backend.sh',
                            "DEPLOY_IMAGE='$image' /bin/bash /opt/devops-deploy/deploy-backend.sh"
                        )


                        $parametersFile = Join-Path $env:WORKSPACE "ssm-deploy-parameters.json"

                        try {
                            @{ commands = $remoteCommands } |
                                ConvertTo-Json -Depth 5 |
                                Set-Content -LiteralPath $parametersFile -Encoding ascii

                            $parametersUri = ([System.Uri]::new($parametersFile)).AbsoluteUri

                            
                            Write-Host "Submitting deployment command to SSM..."
                            $commandId = aws ssm send-command `
                            --instance-ids $instanceId `
                            --document-name AWS-RunShellScript `
                            --parameters "file://$parametersFile" `
                            --query "Command.CommandId" `
                            --output text


                            if ($LASTEXITCODE -ne 0 -or
                                $commandId -notmatch '^[0-9a-fA-F-]{36}$') {
                                throw "SSM command submission failed."
                            }

                            Write-Host "SSM command ID: $commandId"
                            Write-Host "Waiting for SSM execution status..."

                            $deadline = (Get-Date).AddMinutes(15)
                            $finalStatus = ""

                            while ((Get-Date) -lt $deadline) {
                                Start-Sleep -Seconds 5

                                $status = aws ssm get-command-invocation `
                                    --command-id $commandId `
                                    --instance-id $instanceId `
                                    --query "Status" `
                                    --output text 2>$null

                                if ($LASTEXITCODE -ne 0) {
                                    continue
                                }

                                $status = "$status".Trim()

                                if ($status -in @(
                                    "Success", "Cancelled", "TimedOut",
                                    "Failed", "Undeliverable", "Terminated",
                                    "InvalidPlatform", "AccessDenied"
                                )) {
                                    $finalStatus = $status
                                    break
                                }
                            }

                            if (-not $finalStatus) {
                                throw "Jenkins timed out waiting for SSM. The remote command may still be running. Command ID: $commandId"
                            }

                            if ($finalStatus -ne "Success") {
                                Write-Host "SSM final status: $finalStatus"

                                $details = aws ssm get-command-invocation `
                                    --command-id $commandId `
                                    --instance-id $instanceId `
                                    --query "StandardErrorContent" `
                                    --output text

                                if ($LASTEXITCODE -eq 0 -and
                                    $details -and $details -ne "None") {
                                    Write-Host $details
                                }

                                throw "Backend deployment failed. SSM status: $finalStatus"
                            }

                            Write-Host "SSM reports successful command execution."
                        }
                        finally {
                            Remove-Item -LiteralPath $parametersFile `
                                -Force -ErrorAction SilentlyContinue
                        }
                    '''
                }
            }
        }


    }
}
