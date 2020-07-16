#!/bin/bash
# sudo chmod +x *.sh
# ./delete-taskcat.sh 

PREFIX=tCaT
S3_PREFIX=tcat
# Name used in .taskcat.yml
PROJECT_NAME=ccoa

AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')

# Generated Code by TaskCat. For example: 7806754vf2r1494aa8b64d1av821418881
TASKCAT_CODE=${1:-TBD}  
# Generated App Code for Nested Stacks. For example: 2G44LSVW82291
NESTED_APP_CODE=${2:-TBD}

echo Environment: $TASKCAT_CODE

echo "Removing buckets previously used by this script"
aws s3api list-buckets --query 'Buckets[?starts_with(Name, `'$S3_PREFIX-$PROJECT_NAME'`) == `true`].[Name]' --output text | xargs -I {} aws s3 rb s3://{} --force


# echo "Deleting ccoa-taskcat stack"
# aws s3api list-buckets --query 'Buckets[?starts_with(Name, `ccoa`) == `true`].[Name]' --output text | xargs -I {} aws s3 rb s3://{} --force
# aws cloudformation delete-stack --stack-name ccoa-taskcat
# aws cloudformation wait stack-delete-complete --stack-name

# Remove Config Recorder
echo "Deleting ccoa-cr stack"
aws cloudformation delete-stack --stack-name ccoa-cr
aws cloudformation wait stack-delete-complete --stack-name ccoa-cr

# Lesson 6
echo "Deleting $PREFIX-$PROJECT_NAME-lesson6-continuous-$TASKCAT_CODE-$AWS_REGION stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-lesson6-continuous-$TASKCAT_CODE-$AWS_REGION
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson6-continuous-$TASKCAT_CODE-$AWS_REGION

echo "Deleting $PREFIX-$PROJECT_NAME-lesson6-continuous-$TASKCAT_CODE stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-lesson6-continuous-$TASKCAT_CODE
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson6-continuous-$TASKCAT_CODE

# Lesson 5
echo "Deleting $PREFIX-$PROJECT_NAME-l5-cr-$TASKCAT_CODE stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-l5-cr-$TASKCAT_CODE
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson5-config-recorder-$TASKCAT_CODE

echo "Deleting $PREFIX-$PROJECT_NAME-lesson5-remediation-$TASKCAT_CODE stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-lesson5-remediation-$TASKCAT_CODE
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson5-remediation-$TASKCAT_CODE

# Lesson 3
echo "Deleting $PREFIX-$PROJECT_NAME-lesson3-config-rules-s3-$TASKCAT_CODE stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-lesson3-config-rules-s3-$TASKCAT_CODE
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson3-config-rules-s3-$TASKCAT_CODE

# Lesson 2
echo "Deleting $PREFIX-$PROJECT_NAME-lesson2-cfn-nag-$TASKCAT_CODE stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-lesson2-cfn-nag-$TASKCAT_CODE
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson2-cfn-nag-$TASKCAT_CODE

# Lesson 1
echo "Deleting $PREFIX-$PROJECT_NAME-lesson1-pipeline-$TASKCAT_CODE stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-lesson1-pipeline-$TASKCAT_CODE
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson1-pipeline-$TASKCAT_CODE

echo "Deleting $PREFIX-$PROJECT_NAME-lesson1-sqs-$TASKCAT_CODE stack"
aws cloudformation delete-stack --stack-name $PREFIX-$PROJECT_NAME-lesson1-sqs-$TASKCAT_CODE
aws cloudformation wait stack-delete-complete --stack-name $PREFIX-$PROJECT_NAME-lesson1-sqs-$TASKCAT_CODE