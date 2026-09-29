module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.application_name
  cidr = "10.0.0.0/20"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.application_name
  kubernetes_version = local.kubernetes_version

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    general = {
      instance_types = [local.node_group_instance_type]

      min_size     = local.node_group_size
      max_size     = local.node_group_size
      desired_size = local.node_group_size
    }
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

module "load_balancer_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "${local.application_name}-lbc"

  attach_aws_lb_controller_policy = true

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name      = "aws-load-balancer-controller"
  namespace = "kube-system"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "region"
      value = local.aws_region
    },
    {
      name  = "vpcId"
      value = module.vpc.vpc_id
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
  ]

  depends_on = [
    module.load_balancer_controller_pod_identity,
  ]
}

module "image_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket        = "${local.application_name}-images"
  force_destroy = true

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false

  attach_policy = true

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid       = "PublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${module.image_bucket.s3_bucket_arn}/*"
      },
    ]
  })
}

module "image_services_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "${local.application_name}-pod-identity"

  attach_custom_policy = true

  policy_statements = [
    {
      sid       = "S3ImageUpload"
      actions   = ["s3:PutObject", "s3:DeleteObject"]
      resources = ["${module.image_bucket.s3_bucket_arn}/*"]
    },
  ]

  associations = {
    user_service = {
      cluster_name    = module.eks.cluster_name
      namespace       = "default"
      service_account = "user-service"
    }

    post_service = {
      cluster_name    = module.eks.cluster_name
      namespace       = "default"
      service_account = "post-service"
    }

    ad_service = {
      cluster_name    = module.eks.cluster_name
      namespace       = "default"
      service_account = "ad-service"
    }
  }
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 3.0"

  repository_name = local.application_name

  repository_force_delete = true
  create_lifecycle_policy = false
}
