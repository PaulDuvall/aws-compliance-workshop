# Setup

https://docs.aws.amazon.com/AmazonS3/latest/user-guide/add-bucket-policy.html

## Create an SNS Topic and Subscription

Replace `my-email@example.com` with your email address.

```
aws sns create-topic --name aws-config-topic

aws sns subscribe --topic-arn arn:aws:sns:$(aws configure get region --output text):$(aws sts get-caller-identity --output text --query 'Account'):aws-config-topic --protocol email --notification-endpoint my-email@example.com

```

1. Delete the S3 bucket used by AWS Config

```
aws s3 rb s3://$(aws sts get-caller-identity --output text --query 'Account')-config-recorder-stack-awsconfig --force

aws s3 rb s3://config-bucket-$(aws sts get-caller-identity --output text --query 'Account') --force
```

2. List any AWS Config Recorders


```
aws configservice describe-configuration-recorders
```

3. Run the command below replacing `CONFIG-RECORDER-NAME` with the output from the above command

```
aws configservice delete-configuration-recorder --configuration-recorder-name CONFIG-RECORDER-NAME 
```

4. List any AWS Config Delivery Channels

```
aws configservice describe-delivery-channels
```

5. Run the command below replacing `DELIVERY-CHANNEL-NAME` with the output from the above command (the name is probably `default`):


```
aws configservice delete-delivery-channel --delivery-channel-name DELIVERY-CHANNEL-NAME
```


## Create CloudFormation Template to enable ConfigRecorder

![Compliance CloudFormation](https://github.com/PaulDuvall/aws-compliance-workshop/wiki/img/compliance/compliance-cfn-pipeline.png)

1. Create `lesson0` directory from your AWS Cloud9 environment: 

```
mkdir ~/environment/lesson0
```

2. Change directory: 

```
cd ~/environment/lesson0
```

3. Create a new file 

```
touch config-recorder.yml
```

4. Paste the contents of the CloudFormation template into `config-recorder.yml` and save the file 

```AWSTemplateFormatVersion: '2010-09-09'
Description: Setup AWS Config Service
Resources:
  ConfigBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain
    Properties:
      AccessControl: BucketOwnerFullControl
      BucketName: !Sub '${AWS::AccountId}-${AWS::StackName}-awsconfig'
  ConfigTopic:
    Type: AWS::SNS::Topic
  DeliveryChannel: 
    Type: AWS::Config::DeliveryChannel
    Properties: 
      ConfigSnapshotDeliveryProperties: 
        DeliveryFrequency: "Six_Hours"
      S3BucketName: 
        Ref: ConfigBucket
      SnsTopicARN: 
        Ref: ConfigTopic
  ConfigBucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref 'ConfigBucket'
      PolicyDocument:
        Version: '2012-10-17'
        Id: PutObjPolicy
        Statement:
          - Sid: DenyUnEncryptedObjects
            Effect: Deny
            Principal: '*'
            Action: s3:PutObject
            Resource: !Join
              - ''
              - - 'arn:aws:s3:::'
                - !Ref 'ConfigBucket'
                - /*
            Condition:
              StringNotEquals:
                s3:x-amz-server-side-encryption: AES256
  ConfigTopic:
    Type: AWS::SNS::Topic
    Properties:
      DisplayName: config-sns-topic
      TopicName: config-sns-topic
  ConfigRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
          - Action:
              - sts:AssumeRole
            Effect: Allow
            Principal:
              Service:
                - config.amazonaws.com
        Version: '2012-10-17'
      Path: /
      Policies:
        - PolicyDocument:
            Statement:
              - Effect: Allow
                Action: sns:Publish
                Resource: !Ref 'ConfigTopic'
              - Effect: Allow
                Action:
                  - s3:PutObject
                Resource:
                  - !Join
                    - ''
                    - - 'arn:aws:s3:::'
                      - !Ref 'ConfigBucket'
                      - /AWSLogs/
                      - !Ref 'AWS::AccountId'
                      - /*
                Condition:
                  StringLike:
                    s3:x-amz-acl: bucket-owner-full-control
              - Effect: Allow
                Action:
                  - s3:GetBucketAcl
                Resource: !Join
                  - ''
                  - - 'arn:aws:s3:::'
                    - !Ref 'ConfigBucket'
          PolicyName: root
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSConfigRole
  ConfigRecorder:
    Type: AWS::Config::ConfigurationRecorder
    Properties:
      Name: aws-config-recorder
      RecordingGroup:
        AllSupported: true
        IncludeGlobalResourceTypes: true
      RoleARN: !GetAtt 'ConfigRole.Arn'
Outputs:
  StackName:
    Value: !Ref 'AWS::StackName'
```


## Launch the CloudFormation stack to enable the ConfigRecorder

From your AWS Cloud9 environment, run the following command:

```
aws cloudformation create-stack --stack-name config-recorder-stack --template-body file:///home/ec2-user/environment/lesson0/config-recorder.yml --capabilities CAPABILITY_NAMED_IAM --disable-rollback
```

## Create an S3 Bucket

```
aws s3 mb s3://s3-bucket-public-write-prohibited-$(aws sts get-caller-identity --output text --query 'Account') --region us-east-1
```

### Create an S3 Bucket Policy and assign to Bucket

**CAREFUL: This gives public write access to `mybucketname` (replace with the name of the bucket you just created). This is for demonstration purposes and AWS highly recommends that you never grant any kind of public access to your S3 bucket.**

1. Create a new file called `policy.json`.

```
cd ~/environment/lesson0
touch policy.json
```

2. Open the `policy.json` file and paste the contents below and save the file.

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:Abort*",
        "s3:DeleteObject",
        "s3:GetBucket*",
        "s3:GetObject",
        "s3:List*",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::mybucketname",
        "arn:aws:s3:::mybucketname/*"
      ]
    }
  ]
}
```

3. Apply the S3 Bucket Policy to the Bucket by running the command below:

```
aws s3api put-bucket-policy --bucket s3-bucket-public-write-prohibited-$(aws sts get-caller-identity --output text --query 'Account') --policy file:///home/ec2-user/environment/lesson0/policy.json
```

## Create an AWS Config Rule


Alternatively, you can use the  [AWS Config Console](https://console.aws.amazon.com/config/home?region=us-east-1#/rules/view) to add a rule

1. Create a new file called `s3-bucket-public-write-prohibited.json`.

```
cd ~/environment/lesson0
touch s3-bucket-public-write-prohibited.json
```

2. Open the `s3-bucket-public-write-prohibited.json` file and paste the contents below and save the file.


```
{
  "ConfigRuleName":"S3BucketPublicWriteProhibited",
  "Description":"Checks that your Amazon S3 buckets do not allow public write access. The rule checks the Block Public Access settings, the bucket policy, and the bucket access control list (ACL).",
  "InputParameters":{

  },
  "Scope":{
    "ComplianceResourceTypes":[
      "AWS::S3::Bucket"
    ]
  },
  "Source":{
    "Owner":"AWS",
    "SourceIdentifier":"S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }
}
```

3. Run the command to apply the Config Rule

```
aws configservice put-config-rule --config-rule file:///home/ec2-user/environment/lesson0/s3-bucket-public-write-prohibited.json
```

```

s3-bucket-public-write-prohibited
S3_BUCKET_PUBLIC_WRITE_PROHIBITED

AutomationAssumeRole
Message
TopicArn

arn:aws:iam::123456789012:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM

arn:aws:sns:us-east-1:123456789012:SNSTopicName

AWS-PublishSNSNotification
```

## Create a IAM Role for Lambda function

1. Create a new file called `lambda-s3-remediation-policy.json`:

```
cd ~/environment/lesson0
touch lambda-s3-remediation-policy.json
```

2. Open the `lambda-s3-remediation-policy.json` file and paste the contents below and save the file:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:*",
                "config:*",
                "iam:*",
                "lambda:*",
                "logs:*",
                "s3:*"
            ],
            "Resource": "*"
        }
    ]
}

```

3. Create the IAM Role

Create a new [IAM Role](https://console.aws.amazon.com/iam/home?region=us-east-1#/roles). Give it the name: `pmd-lambda-s3-remediation-role`.

```
aws iam create-role --role-name pmd-lambda-s3-remediation-role --assume-role-policy-document file:///home/ec2-user/environment/lesson0/lambda-s3-remediation-policy.json 
```

4. Create the IAM Policy (OPTIONAL)

```
aws iam create-policy --policy-name pmd-lambda-s3-remediation-policy --policy-document file:///home/ec2-user/environment/lesson0/lambda-s3-remediation-policy.json
```

## Create a Lambda Function

Create a new [Lambda Function](https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions) and paste the following Node.js code below and save the function.

```
var AWS = require('aws-sdk');

exports.handler = function(event) {
  console.log("request:", JSON.stringify(event, undefined, 2));

    var s3 = new AWS.S3({apiVersion: '2006-03-01'});
    var resource = event['detail']['requestParameters']['evaluations'];
    console.log("evaluations:", JSON.stringify(resource, null, 2));
    
  
for (var i = 0, len = resource.length; i < len; i++) {
  if (resource[i]["complianceType"] == "NON_COMPLIANT")
  {
      console.log(resource[i]["complianceResourceId"]);
      var params = {
        Bucket: resource[i]["complianceResourceId"]
      };

      s3.deleteBucketPolicy(params, function(err, data) {
        if (err) console.log(err, err.stack); // an error occurred
        else     console.log(data);           // successful response
      });
  }
}


};
```

## CloudWatch Events Rule Event Pattern

```
{
  "source":[
    "aws.config"
  ],
  "detail":{
    "requestParameters":{
      "evaluations":{
        "complianceType":[
          "NON_COMPLIANT"
        ]
      }
    },
    "additionalEventData":{
      "managedRuleIdentifier":[
        "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
      ]
    }
  }
}
```

