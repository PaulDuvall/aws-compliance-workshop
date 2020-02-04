# Run all AWS Config Managed Rules in CloudFormation

```
aws s3 mb s3://ccoa-mcr-$(aws sts get-caller-identity --output text --query 'Account')
cd ~/environment/aws-compliance-workshop/lesson0-setup/managed-config-rules
zip ccoa-mcr-examples.zip *.*
aws s3 sync ~/environment/aws-compliance-workshop/lesson0-setup/managed-config-rules s3://ccoa-mcr-$(aws sts get-caller-identity --output text --query 'Account')
```


```
aws cloudformation create-stack --stack-name managed-config-rules-pipeline --template-body file:///home/ec2-user/environment/aws-compliance-workshop/lesson0-setup/managed-config-rules/managed-config-rules-pipeline.yml --parameters ParameterKey=EmailAddress,ParameterValue=fake-email@fake-fake-fake-email.com ParameterKey=CodeCommitS3Bucket,ParameterValue=ccoa-mcr-$(aws sts get-caller-identity --output text --query 'Account') ParameterKey=CodeCommitS3Key,ParameterValue=ccoa-mcr-examples.zip --capabilities CAPABILITY_NAMED_IAM --disable-rollback
```