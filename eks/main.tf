terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.44.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file       = false
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}




module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_enabled_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  eks_managed_node_groups = {
    nodegroup-1 = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 2
      max_size       = 4
      spot           = true

      iam_role_additional_policies = {
        albIngress = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
        cloudWatch = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
        autoScaler = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
        ebs        = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        xRay       = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
      }
    }
  }

  fargate_profiles = {
    on-fargate = {
      selectors = [
        {
          namespace = "on-fargate"
        }
      ]
    }

    myprofile = {
      selectors = [
        {
          namespace = "prod"
          labels = {
            stack = "frontend"
          }
        }
      ]
    }
  }

  cluster_addons = {
    vpc-cni                         = {}
    coredns                         = {}
    kube-proxy                      = {}
    aws-ebs-csi-driver              = {}
    amazon-cloudwatch-observability = {}
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_iam_policy" "alb_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam-policy.json")
}

module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.34.0"

  create_role = true
  role_name   = "alb-controller-${module.eks.cluster_name}"

  provider_url = module.eks.oidc_provider
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:aws-load-balancer-controller"
  ]

  role_policy_arns = [
    aws_iam_policy.alb_controller.arn
  ]
}

resource "aws_iam_policy" "alb_controller_extra" {
  name        = "alb-controller-extra-${module.eks.cluster_name}"
  description = "Additional permissions for ALB controller"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListInstanceProfiles",
          "tag:GetResources"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller_extra" {
  role       = module.alb_controller_irsa.iam_role_name
  policy_arn = aws_iam_policy.alb_controller_extra.arn
}

module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.34.0"

  create_role = true
  role_name   = "cluster-autoscaler-${module.eks.cluster_name}"

  provider_url = module.eks.oidc_provider
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:cluster-autoscaler"
  ]

  role_policy_arns = [
    "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  ]
}

resource "aws_iam_policy" "cluster_autoscaler_extra" {
  name        = "cluster-autoscaler-extra-${module.eks.cluster_name}"
  description = "Additional permissions for Cluster Autoscaler"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "autoscaling:Describe*",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_extra" {
  role       = module.cluster_autoscaler_irsa.iam_role_name
  policy_arn = aws_iam_policy.cluster_autoscaler_extra.arn
}

resource "null_resource" "wait_for_nodes" {
  provisioner "local-exec" {
    command = <<EOT
      for i in {1..30}; do
        if aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --profile ${var.profile} >/dev/null 2>&1 && \
           kubectl get nodes | grep -q Ready; then
          echo "Nodes are Ready!"
          exit 0
        fi
        echo "Waiting for nodes..."
        sleep 10
      done
      echo "Timeout waiting for nodes"
      exit 1
    EOT
  }

  depends_on = [module.eks]
}

provider "helm" {
  alias = "after_nodes"

  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  provider   = helm.after_nodes
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.alb_controller_irsa.iam_role_arn
    }
  ]

  depends_on = [null_resource.wait_for_nodes]
}

resource "helm_release" "cluster_autoscaler" {
  provider   = helm.after_nodes
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"

  set = [
    {
      name  = "autoDiscovery.clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "awsRegion"
      value = var.region
    },
    {
      name  = "rbac.serviceAccount.create"
      value = "true"
    },
    {
      name  = "rbac.serviceAccount.name"
      value = "cluster-autoscaler"
    },
    {
      name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.cluster_autoscaler_irsa.iam_role_arn
    }
  ]

  depends_on = [null_resource.wait_for_nodes]
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --profile ${var.profile}"
  description = "Run this command to update your kubeconfig for kubectl access."
}
