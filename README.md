# aws-redshift


COPY products FROM redshift-us-east-2-epomatti.s3.amazonaws.com/data/ CREDENTIALS access_credentials



```sql
copy table from 's3://<your-bucket-name>/load/key_prefix' 
credentials 'aws_iam_role=arn:aws:iam::<aws-account-id>:role/<role-name>'
options;
```