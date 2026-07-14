##############################################################
# terraform.tfvars
# Edit these values for your setup
##############################################################

aws_region   = "us-east-1"
project_name = "hasham-cicd"

# GitHub — repo must exist before terraform apply
github_owner  = "i-am-hasham"
github_repo   = "flask-cicd-app"
github_branch = "main"

# ECR
ecr_repo_name = "flask-cicd-app"

# EC2 — target server where app deploys
instance_type = "t2.micro"
ami           = "ami-0c7217cdde317cfec"
key_pair_name = "hasham-key"
my_ip         = "110.93.246.157/32"   # replace with your real IP

# App
app_port       = 5000
container_name = "flask-cicd-app"
