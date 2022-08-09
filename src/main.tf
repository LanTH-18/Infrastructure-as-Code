data "aws_availability_zones" "available_zones" {}
# KMS Secrets
resource "aws_kms_key" "eks_key" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

############## EKS Cluster Create ##############
resource "aws_eks_cluster" "remediation" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster-role.arn
  tags     = var.tags
  version  = var.version 
  vpc_config {
      security_group_ids  = ["${aws_security_group.eks-sg.id}"]
      subnet_ids          = "${aws_subnet.eks-subnet.*.id}"
  }
  
  enabled_cluster_log_types = ["api", "audit"]

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_key.arn
    }
    resources = ["secrets"]
  }
  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    resource.aws_kms_key.eks_key,
    aws_cloudwatch_log_group.example,
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}


############## Cluster Role #############################
resource "aws_iam_role" "cluster-role" {
  name = "eks-cluster-example"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster-role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster-role.name
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
}


############## VPC Create######################

resource "aws_vpc" "for_eks" {
  cidr_block = "10.0.0.0/16"
  tags = var.tags
}
# Subnets
resource "aws_subnet" "eks-subnet" {
   count = 2

  availability_zone = "${data.aws_availability_zones.available_zones.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.for_eks.id}"
}
# IGW for EKS
resource "aws_internet_gateway" "gateway" {
    # Attaches the gateway to the VPC.
    vpc_id = "${aws_vpc.for_eks.id}"
}
# Determines where network traffic from the gateway
# will be directed. 
resource "aws_route_table" "route-table" {
  vpc_id = "${aws_vpc.for_eks.id}"

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.gateway.id}"
  }
}
resource "aws_route_table_association" "table_association" {
    count = 2
    subnet_id       = "${aws_subnet.eks-subnet.*.id[count.index]}"
    route_table_id  = "${aws_route_table.route-table.id}"
  
}

############### Cluster Security group Create ##################
resource "aws_security_group" "eks-sg" {
  vpc_id = aws_vpc.for_eks.id
  name = "eks-cluster-sg"
  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "security-group-worker" {
    name = "worker-node"
    description = "Security group for worker nodes"
    vpc_id = "${aws_vpc.for_eks.id}"
    egress {
        cidr_blocks = [ "0.0.0.0/0" ]
        from_port = 0
        to_port = 0
        protocol = "-1"
    }
}

# Security Group Rule
resource "aws_security_group_rule" "ingress-self" {
    description = "Allow communication among nodes"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    security_group_id = "${aws_security_group.security-group-worker.id}"
    source_security_group_id = "${aws_security_group.security-group-worker.id}"
    type = "ingress"
}

resource "aws_security_group_rule" "ingress-cluster-https" {
    description = "Allow worker to receive communication from the cluster control plane"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_group_id = "${aws_security_group.security-group-worker.id}"
    source_security_group_id = "${aws_security_group.eks-sg.id}"
    type = "ingress"
    
}

resource "aws_security_group_rule" "ingress-cluster-others" {
    description = "Allow worker to receive communication from the cluster control plane"
    from_port = 1025
    to_port = 65535
    protocol = "tcp"
    security_group_id = "${aws_security_group.security-group-worker.id}"
    source_security_group_id = "${aws_security_group.eks-sg.id}"
    type = "ingress"
}

# Worker Access to Master

resource "aws_security_group_rule" "cluster-node-ingress-http" {
    description                     = "Allows pods to communicate with the cluster API server"
    from_port                       = 443
    to_port                         = "443"
    protocol                        = "tcp"
    security_group_id               = "${aws_security_group.eks-sg.id}"
    source_security_group_id        = "${aws_security_group.security-group-worker.id}"
    type                            = "ingress"
  
}
############### Worker node role ###################
resource "aws_iam_role" "iam-role-worker"{
    name = "eks-worker"
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

# allows Amazon EKS worker nodes to connect to Amazon EKS Clusters.
resource "aws_iam_role_policy_attachment" "iam-role-worker-AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role = "${aws_iam_role.iam-role-worker.name}"
}

# This permission is required to modify the IP address configuration of worker nodes
resource "aws_iam_role_policy_attachment" "iam-role-worker-AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role = "${aws_iam_role.iam-role-worker.name}"
}

# Allows to list repositories and pull images
resource "aws_iam_role_policy_attachment" "iam-role-worker-AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role = "${aws_iam_role.iam-role-worker.name}"

}

# An instance profile represents an EC2 instances (Who am I?)
# and assumes a role (what can I do?).
resource "aws_iam_instance_profile" "worker-node" {
    name = "worker-node"
    role = "${aws_iam_role.iam-role-worker.name}"
}