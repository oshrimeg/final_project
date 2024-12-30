provider "aws" {
  region = "us-east-1"  
}

resource "aws_eip" "new_ip" {
  domain = "vpc"
}

# my ec2 instance (compute)
resource "aws_instance" "ec2-instance1" {
    ami           = "ami-0866a3c8686eaeeba"
    instance_type = "t2.micro" # free tier # 1 vCPU, 1 GiB RAM
    key_name = "first-key"
    associate_public_ip_address = true
    iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
    tags = {
        Name = "Jenkins-Master"
    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y

                sudo apt install unzip

                sudo apt install openjdk-17-jdk -y

                sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
                https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
                echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
                https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
                /etc/apt/sources.list.d/jenkins.list > /dev/null
                sudo apt-get update
                sudo apt-get install jenkins -y
                sudo systemctl start jenkins
                sudo systemctl enable jenkins

                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                sudo chmod +x kubectl
                sudo mv kubectl /usr/local/bin/

                ARCH=amd64
                PLATFORM=$(uname -s)_$ARCH
                curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
                tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
                sudo mv /tmp/eksctl /usr/local/bin

                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install
                EOF

    vpc_security_group_ids = [aws_security_group.JenkinsServer.id]
    subnet_id            = module.vpc.public_subnets[0]
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2-instance1.id
  allocation_id = aws_eip.new_ip.id
}


resource "aws_security_group" "JenkinsServer" {
    vpc_id = module.vpc.vpc_id 
    tags = {
        Name = "Allow HTTP and SSH inbound traffic"
        description = "Allow HTTP and SSH inbound traffic"
    }
    name        = "JenkinsServer"
    description = "Allow HTTP and SSH inbound traffic"

    ingress {
        description = "HTTP"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # allow ssh
    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = "connect_to_eks"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

variable "policy_arns" {
  type    = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}
resource "aws_iam_role_policy_attachment" "example" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.role.name
}


# resource "aws_default_vpc" "default" {
#   tags = {
#     Name = "Default VPC"
#   }
# }

# import {
#   to = aws_default_vpc.default
#   id = "vpc-0308ade43f2bf2924"
# }


output "IP" {
    value = aws_eip.new_ip.address
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"


  name = "my-demo-vpc"
  cidr = "10.10.0.0/16"


  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets  = ["10.10.101.0/24", "10.10.102.0/24"]


  enable_nat_gateway = true
  single_nat_gateway = true
  


#   enable_vpn_gateway = true




  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}



module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-terra-cluster"
  cluster_version = "1.31"
  subnet_ids         = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets
  vpc_id          = module.vpc.vpc_id
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true
  


  eks_managed_node_groups  = {
    terra-eks = {
        min_size = 1
        max_size = 1
        desired_size = 1
       
        instance_types = ["t3.medium"]
    }


  }
  

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }


  authentication_mode = "API_AND_CONFIG_MAP"
}

resource "aws_security_group_rule" "allow_jenkins_ingress" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  source_security_group_id = aws_security_group.JenkinsServer.id
  security_group_id = module.eks.cluster_security_group_id
  }

# Data source to get the EKS cluster details
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name  # Replace with your EKS cluster name

  depends_on = [ module.eks ]
}

# Data source to get the authentication token for the cluster
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name # Replace with your EKS cluster name

  depends_on = [ module.eks ]
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "aws_ebs_volume" "db_pv_volume" {
  availability_zone = "us-east-1a"  # e.g., us-west-2a
  size              = 20  # Size in GB
  tags = {
    Name = "db-persistent-volume"
  }
}

resource "kubernetes_persistent_volume" "db-pv" {
  metadata {
    name = "db-pv"
  }
  spec {
    capacity = {
      storage = "20Gi"
    }
    volume_mode = "Filesystem"

    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
        aws_elastic_block_store {
          volume_id = aws_ebs_volume.db_pv_volume.id
          fs_type   = "ext4"
        }    
    }
    storage_class_name = "gp2"
  }
  depends_on = [ module.eks ]
}


resource "kubernetes_persistent_volume_claim" "db_pvc" {
  metadata {
    name      = "db-pvc"
    namespace = "default"  # Change to your desired namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.db-pv.metadata[0].name
    storage_class_name = "gp2"
  }
  
  depends_on = [ module.eks ]
}

# # IAM Role for EFS CSI Driver
# resource "aws_iam_role" "efs_csi_driver_role" {
#   name = "EFS-CSI-Driver-Role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action    = "sts:AssumeRole"
#         Effect    = "Allow"
#         Principal = {
#           Service = "eks.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# # IAM Policy for EFS CSI Driver
# resource "aws_iam_policy" "efs_csi_driver_policy" {
#   name        = "EFS-CSI-Driver-Policy"
#   description = "EFS CSI driver policy for EKS"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action   = [
#           "elasticfilesystem:DescribeFileSystems",
#           "elasticfilesystem:CreateMountTarget",
#           "elasticfilesystem:DeleteMountTarget",
#           "elasticfilesystem:DescribeMountTargets",
#           "elasticfilesystem:DescribeMountTargetSecurityGroups",
#           "elasticfilesystem:CreateTags",
#           "*"
#         ]
#         Effect   = "Allow"
#         Resource = "*"
#       }
#     ]
#   })
# }

# # Attach the policy to the EFS CSI driver role
# resource "aws_iam_role_policy_attachment" "efs_csi_driver_attachment" {
#   policy_arn = aws_iam_policy.efs_csi_driver_policy.arn
#   role       = aws_iam_role.efs_csi_driver_role.name
# }
# # Create EKS Addon for EFS CSI driver
# resource "aws_eks_addon" "efs_csi_driver" {
#   cluster_name = data.aws_eks_cluster.cluster.name
#   addon_name   = "efs-csi-driver"
#   addon_version = "v2.1.2-eksbuild.1"  # Specify the version of the EFS CSI driver

#   # Configure the IAM role for the EFS CSI driver
#   service_account_role_arn = aws_iam_role.efs_csi_driver_role.arn
#   depends_on = [ module.eks ]
# }

# Security Group that allows all inbound and outbound traffic
# resource "aws_security_group" "allow_all" {
#   name        = "allow-all-traffic"
#   description = "Security Group that allows all inbound and outbound traffic"
#   vpc_id      = module.vpc.vpc_id

#   # Allow all inbound traffic from all sources (0.0.0.0/0)
#   ingress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"  # -1 means all protocols
#     cidr_blocks = ["0.0.0.0/0"]  # All IP addresses
#   }

#   # Allow all outbound traffic to all destinations (0.0.0.0/0)
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"  # -1 means all protocols
#     cidr_blocks = ["0.0.0.0/0"]  # All IP addresses
#   }

#   tags = {
#     Name = "allow-all-traffic"
#   }
# }

# # Create EFS File System
# resource "aws_efs_file_system" "efs_db" {
#   performance_mode = "generalPurpose"  # Can be "generalPurpose" or "maxIO"
#   tags = {
#     Name = "my-efs-file-system"
#   }
# }

# # Create EFS Mount Targets in each AZ
# resource "aws_efs_mount_target" "db_efs_mount" {
#   for_each = zipmap(
#     tolist(range(length(module.vpc.private_subnets))), # Create an index list based on the number of subnets
#     module.vpc.private_subnets # Map it to the actual subnet IDs
#   )

#   file_system_id = aws_efs_file_system.efs_db.id
#   subnet_id      = each.value  # `each.value` gives the subnet ID
#   security_groups = [aws_security_group.allow_all.id]  # Replace with your actual security group ID
# }

# # Persistent Volume (PV) for EFS
# resource "kubernetes_persistent_volume" "efs_pv" {
#   metadata {
#     name = "efs-pv"
#   }

#   spec {
#     capacity = {
#       storage = "5Gi"
#     }
#     volume_mode = "Filesystem"
#     access_modes = ["ReadWriteMany"]

#     persistent_volume_source {
#       csi {
#         driver = "efs.csi.aws.com"
#         volume_handle = aws_efs_file_system.efs_db.id  # Replace with your EFS file system ID
#       }
#     }
#   }
#   depends_on = [ module.eks, aws_efs_mount_target.db_efs_mount ]
# }

# # Persistent Volume Claim (PVC) for EFS
# resource "kubernetes_persistent_volume_claim" "efs_pvc" {
#   metadata {
#     name      = "efs-pvc"
#     namespace = "default"
#   }

#   spec {
#     access_modes = ["ReadWriteMany"]
#     resources {
#       requests = {
#         storage = "5Gi"
#       }
#     }
#   }
#   depends_on = [ module.eks, kubernetes_persistent_volume.efs_pv, aws_efs_mount_target.db_efs_mount]
# }



# Output the cluster endpoint
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

# Output the cluster kubeconfig command
output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region us-east-1"
}
