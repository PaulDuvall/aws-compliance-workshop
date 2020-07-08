#!/bin/bash
# sudo chmod +x *.sh
# ./delete-taskcat.sh 

AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')

# Generated Code by TaskCat. For example: 7806754vf2r1494aa8b64d1av821418881
TASKCAT=${1:-TBD}  
# Generated App Code for Nested Stacks. For example: 2G44LSVW82291
NESTED_APP_CODE=${2:-TBD}

echo Environment: $TASKCAT

echo "Removing buckets previously used by this script"
aws s3api list-buckets --query 'Buckets[?starts_with(Name, `tcat-ccoa`) == `true`].[Name]' --output text | xargs -I {} aws s3 rb s3://{} --force

echo "Deleting Lesson 6 stacks"
aws cloudformation delete-stack --stack-name tCaT-lesson6-continuous-$TASKCAT-$AWS_REGION
aws cloudformation wait stack-delete-complete --stack-name tCaT-lesson6-continuous-$TASKCAT-$AWS_REGION
aws cloudformation delete-stack --stack-name tCaT-lesson6-continuous-$TASKCAT
aws cloudformation wait stack-delete-complete --stack-name tCaT-lesson6-continuous-$TASKCAT

echo "Deleting Lesson 2 stacks "
aws cloudformation delete-stack --stack-name tCaT-lesson2-cfn-nag-$TASKCAT
aws cloudformation wait stack-delete-complete --stack-name tCaT-lesson2-cfn-nag-$TASKCAT

echo "Deleting Lesson 1 stacks tCaT-ccoa-lesson1-pipeline-$TASKCAT"
aws cloudformation delete-stack --stack-name tCaT-ccoa-lesson1-pipeline-$TASKCAT
aws cloudformation wait stack-delete-complete --stack-name tCaT-ccoa-lesson1-pipeline-$TASKCAT