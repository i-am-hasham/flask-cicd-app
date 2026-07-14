##############################################################
# main.tf — Root orchestrator
#
# Creation order (Terraform resolves automatically):
#   1. data sources (VPC, account ID)
#   2. ECR repo
#   3. S3 artifact bucket (inside codepipeline module)
#   4. IAM roles (needs bucket ARN + ECR ARN)
#   5. SSM parameters
#   6. EC2 (needs instance profile from IAM)
#   7. CodeBuild (needs IAM role)
#   8. CodeDeploy (needs IAM role)
#   9. CodePipeline (needs all above)
##############################################################

# ── Data Sources ──────────────────────────────────────────────
data "aws_caller_identity" "current" {}

# Use default VPC for simplicity
# If you want to use the vpc-project VPC, use remote state instead:
# data "terraform_remote_state" "vpc" { ... }
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── Module 1: ECR ─────────────────────────────────────────────
module "ecr" {
  source    = "./modules/ecr"
  repo_name = var.ecr_repo_name
}

# ── Module 2: CodePipeline (creates artifact S3 bucket) ───────
# Created early because IAM module needs artifact_bucket_arn
module "codepipeline" {
  source = "./modules/codepipeline"

  project_name               = var.project_name
  account_id                 = data.aws_caller_identity.current.account_id
  codepipeline_role_arn      = module.iam.codepipeline_role_arn
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  github_branch              = var.github_branch
  github_token               = var.github_token
  codebuild_project_name     = module.codebuild.project_name
  codedeploy_app_name        = module.codedeploy.app_name
  codedeploy_deployment_group= module.codedeploy.deployment_group_name
}

# ── Module 3: IAM ─────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  artifact_bucket_arn = module.codepipeline.artifact_bucket_arn
  ecr_repo_arn        = module.ecr.repository_arn
}

# ── Module 4: SSM ─────────────────────────────────────────────
module "ssm" {
  source = "./modules/ssm"

  github_token   = var.github_token
  ecr_repo_url   = module.ecr.repository_url
  container_name = var.container_name
}

# ── Module 5: EC2 ─────────────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  project_name     = var.project_name
  ami              = var.ami
  instance_type    = var.instance_type
  subnet_id        = data.aws_subnets.default.ids[0]
  vpc_id           = data.aws_vpc.default.id
  my_ip            = var.my_ip
  key_pair_name    = var.key_pair_name
  instance_profile = module.iam.ec2_instance_profile
}

# ── Module 6: CodeBuild ───────────────────────────────────────
module "codebuild" {
  source = "./modules/codebuild"

  project_name       = var.project_name
  codebuild_role_arn = module.iam.codebuild_role_arn
  ecr_repo_name      = var.ecr_repo_name
  container_name     = var.container_name
  app_port           = var.app_port
  aws_region         = var.aws_region
}

# ── Module 7: CodeDeploy ──────────────────────────────────────
module "codedeploy" {
  source = "./modules/codedeploy"

  project_name        = var.project_name
  codedeploy_role_arn = module.iam.codedeploy_role_arn
}
