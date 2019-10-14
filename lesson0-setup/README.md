# Automatically Remediate Non-Compliant AWS Resources
**Using AWS Config Rules, CloudWatch Events Rules, and Lambda**

```
aws sts get-caller-identity --output text --query 'Account'
```

## Create an S3 Bucket for CloudTrail Trail
`ccoa-cloudtrail-ACCOUNTID`
1. Go to the [S3](https://console.aws.amazon.com/s3/) console
2. Click the **Create bucket** button
3. Enter `ccoa-cloudtrail-ACCOUNTID` in the **Bucket name** field (replacing `ACCOUNTID` with your account id)
4. Click **Next** on the *Configure Options* screen
5. Click **Next** on the *Set Permissions* screen
6. Click **Create bucket** on the *Review* screen

## Create a CloudTrail Trail
`ccoa-cloudtrail`
1. Go to the [CloudTrail](https://console.aws.amazon.com/cloudtrail/) console
2. Click the **Create trail** button
3. Enter **ccoa-cloudtrail** in the *Trail name* field
4. Choose the checkbox next to **Select all S3 buckets in your account** in the *Data events* section
4. Choose the **No** radio button for the *Create a new S3 bucket* field in the *Storage location* section.
5. Choose the S3 bucket you just created from the *S3 bucket* dropdown.
6. Click the **Create** button

## Cloudwatch Logs
1. Go to the [CloudWatch](https://console.aws.amazon.com/cloudwatch/) console


## SNS Topic and Subscription for Config
`ccoa-config-topic`
1. Go to the [Simple Notification Service](https://console.aws.amazon.com/sns/) console.
2. Select **Topics**
3. Click **Create topic**
4. Enter `ccoa-config-topic` in the **Name** and **Display name** fields
5. Click the **Create topic** button
6. Click the **Create subscription** button
7. Choose **email** from the **Protocol** dropdown
8. Enter your **email address** in the **Endpoint** field
9. Click the **Create subscription** button
10. Confirm the subscription once you receive the email from AWS



## Create an S3 Bucket for Config
`ccoa-config-ACCOUNTID`
1. Go to the [S3](https://console.aws.amazon.com/s3/) console

## Create an AWS Config Recorder
1. Go to the [Config](https://console.aws.amazon.com/config/) console

NOTE: This creates a Config Delivery Channel

## Create an S3 Bucket in violation
`ccoa-s3-write-violation-ACCOUNTID`
1. Go to the [S3](https://console.aws.amazon.com/s3/) console

**Create a S3 Bucket Policy**
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

## Create an IAM Policy for Lambda
`ccoa-s3-write-policy`
1. Go to the [IAM](https://console.aws.amazon.com/iam/) console

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


## Create an IAM Role for Lambda
`ccoa-s3-write-role`
1. Go to the [IAM](https://console.aws.amazon.com/iam/) console


## Create a Lambda function
`ccoa-s3-write-remediation`
1. Go to the [Lambda](https://console.aws.amazon.com/lambda/) console


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


## Create a Config Rule (Managed Rule which runs Lambda function)
`ccoa-s3-write-rule`
1. Go to the [Config](https://console.aws.amazon.com/config/) console


1. Publish SNS Topic remediation

## Cloudwatch Event Rule
`ccoa-s3-write-cwe`
1. Go to the [CloudWatch](https://console.aws.amazon.com/cloudwatch/) console


1. Cloudwatch Event Pattern
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

2. Cloudwatch Event Target


==================================================

# Setup CLI

## CloudFormation Resources
* [AWS::S3::Bucket](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html)
* [AWS::CloudTrail::Trail](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-cloudtrail-trail.html)
* [AWS::Logs::LogGroup](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-logs-loggroup.html)
* [AWS::SNS::Topic](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-sns-topic.html)
* [AWS::Config::ConfigurationRecorder](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-configurationrecorder.html)
* [AWS::Config::DeliveryChannel](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-deliverychannel.html)
* [AWS::S3::BucketPolicy](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-policy.html)
* [AWS::IAM::Policy](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-policy.html)
* [AWS::IAM::Role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-role.html)
* [AWS::Lambda::Function](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-function.html)
* [AWS::Config::ConfigRule](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-configrule.html)
* [AWS::Config::RemediationConfiguration](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-remediationconfiguration.html)
* [AWS::Events::Rule](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-events-rule.html)

## Cleanup


```
aws lambda delete-function --function-name "ccoa-s3-write-remediation"
aws events list-targets-by-rule --rule "ccoa-s3-write-cwe"
aws events remove-targets --rule "ccoa-s3-write-cwe" --ids "TARGETIDSFROMABOVE"
aws events delete-rule --name "ccoa-s3-write-cwe"
aws s3 rb s3://arn:aws:s3:::ccoa-s3-public-write-prohibited-$(aws sts get-caller-identity --output text --query 'Account') --force
aws configservice delete-remediation-configuration --config-rule-name s3-bucket-public-write-prohibited-rule
aws configservice delete-config-rule --config-rule-name s3-bucket-public-write-prohibited
aws sns delete-topic --topic-arn "arn:aws:sns:$(aws configure get region --output text):$(aws sts get-caller-identity --output text --query 'Account'):ccoa-config-topic"


```

## Create an SNS Topic and Subscription

Replace `my-email@example.com` with your email address.

```
aws sns create-topic --name ccoa-config-topic

aws sns subscribe --topic-arn arn:aws:sns:$(aws configure get region --output text):$(aws sts get-caller-identity --output text --query 'Account'):ccoa-config-topic --protocol email --notification-endpoint my-email@example.com

```

1. Delete the S3 bucket used by AWS Config

```
aws s3 rb s3://ccoa-awsconfig-$(aws sts get-caller-identity --output text --query 'Account') --force

aws s3 rb s3://config-bucket-$(aws sts get-caller-identity --output text --query 'Account') --force
```

2. List any AWS Config Recorders


```
aws configservice describe-configuration-recorders
```

3. Run the command below replacing `CONFIGRECORDERNAME` with the output from the above command

```
aws configservice delete-configuration-recorder --configuration-recorder-name CONFIGRECORDERNAME 
```

4. List any AWS Config Delivery Channels

```
aws configservice describe-delivery-channels
```

5. Run the command below replacing `DELIVERYCHANNELNAME` with the output from the above command (the name is probably `default`):


```
aws configservice delete-delivery-channel --delivery-channel-name DELIVERYCHANNELNAME
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
      BucketName: !Sub '${AWS::StackName}-${AWS::AccountId}'
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
      DisplayName: !Sub '${AWS::StackName}'-sns-topic
      TopicName: !Sub '${AWS::StackName}'-sns-topic
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
aws cloudformation create-stack --stack-name ccoa-awsconfig --template-body file:///home/ec2-user/environment/lesson0/config-recorder.yml --capabilities CAPABILITY_NAMED_IAM --disable-rollback
```

## Create an S3 Bucket

```
aws s3 mb s3://ccoa-s3-public-write-prohibited-$(aws sts get-caller-identity --output text --query 'Account') --region us-east-1
```

### Create an S3 Bucket Policy and assign to Bucket

**CAREFUL: This gives public write access to `mybucketname` (replace with the name of the bucket you just created). This is for demonstration purposes and AWS highly recommends that you never grant any kind of public access to your S3 bucket.**

1. Create a new file called `policy.json`.

```
cd ~/environment/lesson0
touch policy.json
```

2. Open the `policy.json` file and paste the contents below (replacing `mybucketname` with the name of the bucket you created above. Save the file.

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


Alternatively, you can use the  [AWS Config Console](https://console.aws.amazon.com/config/home?region=us-east-1#/rules/view) to add a rule. Name the rule `s3-bucket-public-write-prohibited-rule`.

1. Create a new file called `s3-bucket-public-write-prohibited.json`.

```
cd ~/environment/lesson0
touch s3-bucket-public-write-prohibited.json
```

2. Open the `s3-bucket-public-write-prohibited.json` file and paste the contents below and save the file.


```
{
  "ConfigRuleName":"s3-bucket-public-write-prohibited-rule",
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

Remediation Action: AWS-PublishSNSNotification

AutomationAssumeRole: arn:aws:iam::123456789012:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM
Message: s3-bucket-public-write-prohibited violated
TopicArn: arn:aws:sns:us-east-1:123456789012:ccoa-config-topic


```

## Create a IAM Role for Lambda function

1. Create a new file called `ccoa-lambda-s3-remediation-policy.json`:

```
cd ~/environment/lesson0
touch ccoa-lambda-s3-remediation-policy.json
```

2. Open the `ccoa-lambda-s3-remediation-policy.json` file and paste the contents below and save the file:

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

3. Create the IAM Policy

```
aws iam create-policy --policy-name ccoa-lambda-s3-remediation-policy --policy-document file:///home/ec2-user/environment/lesson0/ccoa-lambda-s3-remediation-policy.json
```

4. Create the IAM Role

Create a new [IAM Role](https://console.aws.amazon.com/iam/home?region=us-east-1#/roles). Give it the name: `ccoa-lambda-s3-remediation-role` and apply the `ccoa-lambda-s3-remediation-policy` to the new IAM role. 

```
aws iam create-role --role-name ccoa-lambda-s3-remediation-role --assume-role-policy-document file:///home/ec2-user/environment/lesson0/ccoa-lambda-s3-remediation-policy.json 
```



## Create a Lambda Function

Create a new [Lambda Function](https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions) and paste the following Node.js code below and save the function. Name the function `ccoa-s3-write-remediation`

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

[CloudWatch Events Rule](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#rules:). Name it `ccoa-s3-write-cwe`.

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

