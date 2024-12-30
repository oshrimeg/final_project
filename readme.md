Terraform Infrastructure Deployment with EKS and Jenkins for Contacts App
Overview
This project demonstrates the deployment of cloud infrastructure using Terraform, the setup of an Amazon EKS (Elastic Kubernetes Service) cluster to run a Contacts App, and the CI/CD pipeline using Jenkins deployed on an EC2 instance for apply the Contacts App to the eks cluster.


Certainly! Here's a sample README.md file that provides a comprehensive overview of your project. Feel free to adjust it according to your project's specifics.

Terraform Infrastructure Deployment with EKS and Jenkins for Contacts App
Overview
This project demonstrates the deployment of cloud infrastructure using Terraform, the setup of an Amazon EKS (Elastic Kubernetes Service) cluster to run a Contacts App, and the CI/CD pipeline using Jenkins deployed on an EC2 instance. The project automates the provisioning of infrastructure, app deployment, and continuous integration/deployment processes for the Contacts App.


Prerequisites
Infrastructure Overview
Setup Instructions
Deployment Process
Jenkins Configuration
Contacts App


**Prerequisites**

Before you begin, make sure you have Terraform Installed on your local machine. You can install it from Terraform Downloads.

**Infrastructure Overview**

The infrastructure is built using Terraform and consists of the following components:

VPC: Custom Virtual Private Cloud with public and private subnets, NAT Gateway for outbound traffic, and a security group to control access.
Amazon EKS Cluster: A managed Kubernetes cluster to run the Contacts App as a containerized application.
EC2 Instance: A Jenkins instance deployed on EC2 that automates the deployment of the Contacts App to EKS.
IAM Roles and Policies: IAM roles to allow Jenkins EC2 instance and EKS cluster to interact securely with AWS resources.
The architecture ensures that:

EKS is used for app orchestration.
Jenkins, running on EC2, automates app deployments and updates.

**Setup Instructions**

1. Clone the Repository
Clone the repository containing the Terraform configuration and setup files:

bash
Copy code
git clone <repository_url>
cd <repository_name>
2. Configure AWS Credentials
Make sure your AWS CLI is configured with the appropriate credentials to provision resources.


aws configure
3. Initialize Terraform
Navigate to the directory containing your Terraform files and initialize Terraform:

terraform init

4. Apply Terraform Configuration
Run the following Terraform command to see your changes and provision your infrastructure:

terraform plan

terraform apply
This command will ask for confirmation. Type yes to proceed, and Terraform will create the resources in your AWS account.

**add-ons**

you will need to manually get 2 add-ons in eks dashboard:
Amazon EBS CSI Driver
Amazon EKS Pod Identity Agent

**Deployment Process**

Once the infrastructure is set up, the Contacts App is deployed to the EKS cluster. Here's the general flow:

EC2 Instance Setup: Jenkins is deployed on an EC2 instance using Terraform. Jenkins is configured to automate deployment tasks.


**Jenkins Configuration**

Access Jenkins: Once the EC2 instance is deployed, you can access Jenkins by going to the public IP address of the EC2 instance in your browser.

Set Up Credentials: Ensure that Jenkins has the proper AWS credentials to interact with AWS services like EKS and the id is set to aws_credentials.

Create a Jenkins Pipeline:

Set up a Jenkins pipeline for continuous integration and deployment of the Contacts App.
The jenkinsfile configuration will:
Pull the source code from GitHub.
Deploy the app to EKS using Kubernetes manifests.

Jenkins Pipeline:

You will need to copy the jenkinsfile from the git repository and use it with your new jenkins job using pipline. 
The app's Docker container is then deployed to EKS using a Kubernetes deployment.
EKS Cluster: The EKS cluster runs the Contacts App in containers managed by Kubernetes. The app can be accessed via a public service exposed by the cluster.

**Contacts App**

The Contacts App is a simple application that stores and displays contact information. It is containerized using Docker and deployed as a service on the EKS cluster. The app interacts with an underlying database and provides a simple REST API to manage contacts.

Key Features:
View, Add, Edit, and Delete Contacts.
Scalable, running in Kubernetes within EKS.


