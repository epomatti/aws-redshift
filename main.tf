provider "aws" {
  region = local.region
}

locals {
  region = "us-east-2"
}

### Redshift ###

data "aws_iam_policy" "AmazonRedshiftAllCommandsFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess"
}

resource "aws_iam_role" "redshift" {
  name = "RedshiftClusterRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonRedshiftAllCommandsFullAccess" {
  role       = aws_iam_role.redshift.name
  policy_arn = data.aws_iam_policy.AmazonRedshiftAllCommandsFullAccess.arn
}

resource "aws_redshift_cluster" "main" {
  cluster_identifier  = "company-redshift-cluster"
  database_name       = "companydb"
  master_username     = "dwuser"
  master_password     = "P4ssw0rd"
  node_type           = "dc2.large"
  cluster_type        = "single-node"
  number_of_nodes     = 1
  publicly_accessible = true

  default_iam_role_arn = aws_iam_role.redshift.arn
  iam_roles            = [aws_iam_role.redshift.arn]
}
