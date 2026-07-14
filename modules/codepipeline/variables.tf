variable "project_name" {
  type = string
}

variable "account_id" {
  type = string
}

variable "codepipeline_role_arn" {
  type = string
}

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  type = string
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "codebuild_project_name" {
  type = string
}

variable "codedeploy_app_name" {
  type = string
}

variable "codedeploy_deployment_group" {
  type = string
}
