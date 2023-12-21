#!/bin/bash

ecr_repo_url="113304117666.dkr.ecr.eu-west-1.amazonaws.com/mihai-valentin-ecr-task-aws:latest"
echo "here is the url of the ecr: $ecr_repo_url"

# Install Docker
sudo yum update -y
sudo yum install -y docker

# Start Docker service
sudo service docker start

# Log in to ECR
sudo docker login -u AWS -p $(aws ecr get-login-password --region eu-west-1) $ecr_repo_url
#aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ecr_repo_url

# Pull the Docker image
sudo docker pull 113304117666.dkr.ecr.eu-west-1.amazonaws.com/mihai-valentin-ecr-task-aws:latest

# Run the Docker container
sudo docker run -d -p 80:8080 113304117666.dkr.ecr.eu-west-1.amazonaws.com/mihai-valentin-ecr-task-aws:latest