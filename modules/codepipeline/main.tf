##############################################################
# modules/codepipeline/main.tf
# Creates:
#   S3 bucket     — stores pipeline artifacts between stages
#   CodePipeline  — orchestrates Source → Build → Deploy
##############################################################

# ── Artifact Bucket ───────────────────────────────────────────
# Stores files between pipeline stages
# Source stage puts code here → Build stage reads it → Build puts
# built artifacts here → Deploy stage reads them
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-pipeline-artifacts-${var.account_id}"
  force_destroy = true   # allow delete even when bucket has objects

  tags = { Name = "${var.project_name}-pipeline-artifacts" }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CodePipeline ──────────────────────────────────────────────
resource "aws_codepipeline" "app" {
  name     = "${var.project_name}-pipeline"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # ── STAGE 1: Source ─────────────────────────────────────────
  # Watches GitHub for new commits on the specified branch
  # When a commit is detected → triggers the pipeline automatically
  stage {
    name = "Source"
    action {
      name             = "GitHub-Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = var.github_branch
        OAuthToken = var.github_token
        # OAuthToken read from SSM via codepipeline role
        # Webhook auto-created when OAuthToken is provided
      }
    }
  }

  # ── STAGE 2: Build ──────────────────────────────────────────
  # CodeBuild reads source_output (the GitHub code)
  # Runs buildspec.yml: build Docker image → push to ECR
  # Outputs: appspec.yml + scripts/ + imagedefinitions.json
  stage {
    name = "Build"
    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = var.codebuild_project_name
      }
    }
  }

  # ── STAGE 3: Deploy ─────────────────────────────────────────
  # CodeDeploy reads build_output (appspec.yml + scripts)
  # Connects to EC2 via CodeDeploy agent
  # Runs: stop_app → before_install → start_app → validate
  stage {
    name = "Deploy"
    action {
      name            = "CodeDeploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName     = var.codedeploy_app_name
        DeploymentGroupName = var.codedeploy_deployment_group
      }
    }
  }

  tags = { Name = "${var.project_name}-pipeline" }
}
