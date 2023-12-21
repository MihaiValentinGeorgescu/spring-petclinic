echo "Step Nr.1 - VPC creation and tagging with appropriate tags"
vpc_id=$(aws ec2 create-vpc \
    --cidr-block=10.0.0.0/16 \
    --query Vpc.VpcId \
    --output text \
    --region eu-west-1 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value="mihai-valentin-vpc-task"},{Key=Owner,Value="mgeorgescu"},{Key=Project,Value="2023_internship_bucharest"}]')
echo "The id of the vpc is: $vpc_id"

echo "Step Nr.2 - Attach an Internet Gateway to the VPC"
internet_gateway_id=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' \
    --output text \
    --region eu-west-1 \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value="mihai-valentin-gateway-task-aws"},{Key=Owner,Value="mgeorgescu"},{Key=Project,Value="2023_internship_bucharest"}]')
echo "internet gateway id: $internet_gateway_id"

aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $internet_gateway_id \
    --region eu-west-1
echo "Internet Gateway attached to the VPC successfully"

echo "Step Nr.3 - Subnet creation"
subnet_id=$(aws ec2 create-subnet \
    --vpc-id $vpc_id \
    --cidr-block=10.0.0.0/24 \
    --query Subnet.SubnetId \
    --output text \
    --region eu-west-1 \
    --availability-zone eu-west-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value="mihai-valentin-subnet-task-aws"},{Key=Owner,Value="mgeorgescu"},{Key=Project,Value="2023_internship_bucharest"}]')
echo "The subnet id is: $subnet_id"

echo "Step Nr.4 - Create a Route Table"
route_table_id=$(aws ec2 create-route-table \
    --vpc-id $vpc_id \
    --region eu-west-1 \
    --output text \
    --query 'RouteTable.RouteTableId' \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value="mihai-valentin-subnet-task-aws"},{Key=Owner,Value="mgeorgescu"},{Key=Project,Value="2023_internship_bucharest"}]')
echo "Route table created with ID: $route_table_id"

echo "Step Nr.5 - Associate the Route Table with the Subnet"
aws ec2 associate-route-table \
    --route-table-id $route_table_id \
    --subnet-id $subnet_id \
    --region eu-west-1
echo "Route table associated with the subnet successfully"

echo "Step Nr.6 - Create a Default Route for the Route Table"
aws ec2 create-route \
    --route-table-id $route_table_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $internet_gateway_id \
    --region eu-west-1
echo "Default route added to the route table, pointing to the internet gateway"

echo "Step Nr.7 - Elastic Container Registry creation"
elastic_cr=$(aws ecr create-repository \
    --repository-name mihai-valentin-ecr-task-aws \
    --region eu-west-1)
echo "Elastic container registry with the json: $elastic_cr  was created"

echo "Search for ecr url started..."
ecr_repo_url=$(echo "$elastic_cr" | jq -r '.repository.repositoryUri')
echo "ECR repository URL is: $ecr_repo_url"

export ecr_repo_url

echo "Step Nr.8 creation of a new security group started"
security_group_id=$(aws ec2 create-security-group \
    --group-name MySecurityGroup-for-aws-task \
    --description "My security group" \
    --vpc-id $vpc_id \
    --region eu-west-1 \
    --output text)
echo "Security group created with ID: $security_group_id"

echo "Atuhorize ssh conncetion on port 22 inbound traffic"
aws ec2 authorize-security-group-ingress \
    --region eu-west-1 \
    --group-id $security_group_id \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
echo "authorization was successsfull"

echo "Authorizing ICMP (ping) inbound traffic"
aws ec2 authorize-security-group-ingress \
    --region eu-west-1 \
    --group-id $security_group_id \
    --ip-permissions IpProtocol=icmp,FromPort=-1,ToPort=-1,IpRanges='[{CidrIp=0.0.0.0/0}]'
echo "ICMP (ping) authorization was successful"

echo "Authorizing HTTP (port 80) inbound traffic"
aws ec2 authorize-security-group-ingress \
    --region eu-west-1 \
    --group-id $security_group_id \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0
echo "HTTP (port 80) authorization was successful"

echo "Push to ECR repository"
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 113304117666.dkr.ecr.eu-west-1.amazonaws.com
docker build -t mihai-valentin-ecr-task-aws .
docker tag mihai-valentin-ecr-task-aws:latest 113304117666.dkr.ecr.eu-west-1.amazonaws.com/mihai-valentin-ecr-task-aws:latest
docker push 113304117666.dkr.ecr.eu-west-1.amazonaws.com/mihai-valentin-ecr-task-aws:latest
echo "Push was successfull"

echo "Step Nr.9 - EC2 instance creation + allocation of ip address"
instance_info=$(aws ec2 run-instances \
    --iam-instance-profile "Arn=arn:aws:iam::113304117666:instance-profile/allow_ec2_ecr" \
    --image-id ami-02cad064a29d4550c \
    --count 1 \
    --instance-type t3.micro \
    --key-name  cheie3InstantaLinuxBasic \
    --security-group-ids $security_group_id \
    --subnet-id $subnet_id \
    --associate-public-ip-address \
    --region eu-west-1 \
    --user-data file://user_data_script.sh \
    --query Instances[0].InstanceId \
    --output json \
    --block-device-mappings "[{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{\"VolumeSize\":30,\"DeleteOnTermination\":false}}]" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=mihai-valentin-instance-task-aws},{Key=Owner,Value="mgeorgescu"},{Key=Project,Value="2023_internship_bucharest"}]')
echo "instance with id: $instance_info was successfully created"

echo "cleaning instance id because it comes in double quotes"
clean_instance_id=$(echo "$instance_info" | tr -d '"')

echo "Fetching the IP address of the instance with the id $instance_info"
instance_ip=$(aws ec2 describe-instances \
    --region eu-west-1 \
    --instance-ids "$clean_instance_id" \
    --query 'Reservations[].Instances[].PublicIpAddress' \
    --output text)
echo "The ip address of the instance is $instance_ip"
#ami-02cad064a29d4550c - instance id
#sg-0da3429c6d4a60ea3 - sg
#    --query 'Instances[].PublicIpAddress' \
#echo "Step Nr.6 - Install docker on the virtual machine created and run docjer"
#ssh -i /Users/mgeorgescu/Downloads/cheie3InstantaLinuxBasic.pem ec2-user@$instance_ip 'sudo yum install -y docker'
#ssh -i /Users/mgeorgescu/Downloads/cheie3InstantaLinuxBasic.pem ec2-user@$instance_ip 'sudo service docker start'
#echo "Docker was installed successfully"

#echo "Step Nr.7 Run docker image on the vm"
#ssh -i /Users/mgeorgescu/Downloads/cheie3InstantaLinuxBasic.pem ec2-user@$instance_ip 'sudo docker login -u AWS -p $(aws ecr get-login-password --region eu-west-1) $ecr_repo_url'
#ssh -i /Users/mgeorgescu/Downloads/cheie3InstantaLinuxBasic.pem ec2-user@$instance_ip 'sudo docker pull $ecr_repo_url:latest'
#ssh -i /Users/mgeorgescu/Downloads/cheie3InstantaLinuxBasic.pem ec2-user@$instance_ip 'sudo docker run -d -p 80:80 $ecr_repo_url:latest'
#echo "Docker image was run successfully"