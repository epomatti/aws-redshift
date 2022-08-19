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

data "aws_iam_policy" "AmazonS3FullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
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
          Service = ["redshift.amazonaws.com"]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonRedshiftAllCommandsFullAccess" {
  role       = aws_iam_role.redshift.name
  policy_arn = data.aws_iam_policy.AmazonRedshiftAllCommandsFullAccess.arn
}

resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
  role       = aws_iam_role.redshift.name
  policy_arn = data.aws_iam_policy.AmazonS3FullAccess.arn
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
  skip_final_snapshot = true

  default_iam_role_arn = aws_iam_role.redshift.arn
  iam_roles            = [aws_iam_role.redshift.arn]
}

resource "aws_redshiftdata_statement" "create_product_table" {
  cluster_identifier = aws_redshift_cluster.main.cluster_identifier
  database           = aws_redshift_cluster.main.database_name
  db_user            = aws_redshift_cluster.main.master_username
  sql                = file("${path.module}/create-tables.sql")
}

resource "aws_redshiftdata_statement" "create_employees_table" {
  cluster_identifier = aws_redshift_cluster.main.cluster_identifier
  database           = aws_redshift_cluster.main.database_name
  db_user            = aws_redshift_cluster.main.master_username
  sql                = file("${path.module}/create-employees-table.sql")
}

### S3 ###

resource "aws_s3_bucket" "main" {
  bucket = "redshift-${local.region}-epomatti"

  force_destroy = true

  tags = {
    Name = "redshift-bucket"
  }
}

resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "products" {
  bucket = aws_s3_bucket.main.bucket
  key    = "data/products.csv"
  source = "products.csv"
  etag   = filemd5("products.csv")
}

resource "aws_s3_object" "employees" {
  bucket = aws_s3_bucket.main.bucket
  key    = "data/employees.csv"
  source = "employees.csv"
  etag   = filemd5("employees.csv")
}

### Data Pipelines ###

data "aws_iam_policy" "AmazonEC2ReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

data "aws_iam_policy" "AWSCodePipelineFullAccess" {
  arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess"
}

resource "aws_iam_role" "datapipelines" {
  name = "DataPipelinesRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "datapipeline.amazonaws.com",
            "elasticmapreduce.amazonaws.com"
          ]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess_pipelines" {
  role       = aws_iam_role.datapipelines.name
  policy_arn = data.aws_iam_policy.AmazonS3FullAccess.arn
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ReadOnlyAccess" {
  role       = aws_iam_role.datapipelines.name
  policy_arn = data.aws_iam_policy.AmazonEC2ReadOnlyAccess.arn
}

resource "aws_iam_role_policy_attachment" "AWSCodePipelineFullAccess" {
  role       = aws_iam_role.datapipelines.name
  policy_arn = data.aws_iam_policy.AWSCodePipelineFullAccess.arn
}

resource "aws_iam_instance_profile" "guacamole" {
  name = "DataPipelinesEC2InstanceRole"
  role = aws_iam_role.datapipelines.id
}


### Outputs ###

output "bucket" {
  value = aws_s3_bucket.main.bucket_domain_name
}

output "copy" {
  value = "copy products from 's3://${aws_s3_bucket.main.bucket}/${aws_s3_object.products.key}' credentials 'aws_iam_role=${aws_iam_role.redshift.arn}' csv;"
}
