# Automatically Remediate Non-Compliant AWS Resources
**Using AWS Config Rules, CloudWatch Events Rules, and Lambda**

```
aws sts get-caller-identity --output text --query 'Account'
```

# Cleanup

```
aws configure get region --output text
aws configservice describe-configuration-recorders --region REGIONCODE
aws configservice delete-configuration-recorder --configuration-recorder-name CONFIGRECORDERNAME --region REGIONCODE
aws configservice describe-delivery-channels --region REGIONCODE
aws configservice delete-delivery-channel --delivery-channel-name DELIVERYCHANNELNAME --region REGIONCODE
aws s3 rb s3://ccoa-cloudtrail-$(aws sts get-caller-identity --output text --query 'Account') --force --region REGIONCODE
aws s3 rb s3://ccoa-awsconfig-ccoa-config-cloudtrail-$(aws sts get-caller-identity --output text --query 'Account') --force --region REGIONCODE
aws cloudformation delete-stack --stack-name ccoa-config-cloudtrail --region us-east-2 --region REGIONCODE
aws s3 rb s3://ccoa-s3-write-violation-$(aws sts get-caller-identity --output text --query 'Account') --region REGIONCODE
aws iam delete-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --output text --query 'Account'):policy/ccoa-s3-write-policy --region REGIONCODE
aws lambda delete-function --function-name "ccoa-s3-write-remediation" --region REGIONCODE
aws configservice delete-config-rule --config-rule-name ccoa-s3-write-rule --region REGIONCODE
aws events list-targets-by-rule --rule "ccoa-s3-write-cwe" --region REGIONCODE
aws events remove-targets --rule "ccoa-s3-write-cwe" --ids "TARGETIDSFROMABOVE"  --region REGIONCODE
```

# Automated Remediation CloudFormation and CodePipeline with Stack Updates 

## CloudFormation Resources
* [AWS::S3::Bucket](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html)
* [AWS::CloudTrail::Trail](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-cloudtrail-trail.html)
* [AWS::Logs::LogGroup](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-logs-loggroup.html)
* [AWS::SNS::Topic](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-sns-topic.html)
* [AWS::Config::ConfigurationRecorder](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-configurationrecorder.html)
* [AWS::Config::DeliveryChannel](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-deliverychannel.html)
* [AWS::S3::BucketPolicy](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-policy.html)
* [AWS::IAM::Role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-role.html)
* [AWS::Lambda::Function](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-function.html)
* [AWS::Config::ConfigRule](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-configrule.html)
* [AWS::Events::Rule](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-events-rule.html)


## Create CloudFormation Template to enable ConfigRecorder

The following CloudFormation Resources are created in this section:

* [AWS::S3::Bucket](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-bucket.html) (1 for Config Snapshots and 1 for CloudTrail logs)
* [AWS::CloudTrail::Trail](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-cloudtrail-trail.html) (1 for CloudTrail)
* [AWS::SNS::Topic](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-sns-topic.html) (1 for Config and 1 for CloudTrail logs)
* [AWS::Config::ConfigurationRecorder](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-configurationrecorder.html) (1 for Config)
* [AWS::Config::DeliveryChannel](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-config-deliverychannel.html) (1 for Config)
* [AWS::S3::BucketPolicy](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-policy.html) (1 for Config and 1 for CloudTrail logs)
* [AWS::IAM::Role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-role.html) (1 for Config)


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
touch ccoa-cloudtrail.yml
```

4. Paste contents


```
---
AWSTemplateFormatVersion: '2010-09-09'
Parameters:
  OperatorEmail:
    Description: Email address to notify when new logs are published.
    Type: String
Resources:
  S3Bucket:
    DeletionPolicy: Retain
    Type: AWS::S3::Bucket
    Properties: {}
  BucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket:
        Ref: S3Bucket
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Sid: AWSCloudTrailAclCheck
          Effect: Allow
          Principal:
            Service: cloudtrail.amazonaws.com
          Action: s3:GetBucketAcl
          Resource:
            Fn::Join:
            - ''
            - - 'arn:aws:s3:::'
              - Ref: S3Bucket
        - Sid: AWSCloudTrailWrite
          Effect: Allow
          Principal:
            Service: cloudtrail.amazonaws.com
          Action: s3:PutObject
          Resource:
            Fn::Join:
            - ''
            - - 'arn:aws:s3:::'
              - Ref: S3Bucket
              - "/AWSLogs/"
              - Ref: AWS::AccountId
              - "/*"
          Condition:
            StringEquals:
              s3:x-amz-acl: bucket-owner-full-control
  Topic:
    Type: AWS::SNS::Topic
    Properties:
      Subscription:
      - Endpoint:
          Ref: OperatorEmail
        Protocol: email
  TopicPolicy:
    Type: AWS::SNS::TopicPolicy
    Properties:
      Topics:
      - Ref: Topic
      PolicyDocument:
        Version: '2008-10-17'
        Statement:
        - Sid: AWSCloudTrailSNSPolicy
          Effect: Allow
          Principal:
            Service: cloudtrail.amazonaws.com
          Resource: "*"
          Action: SNS:Publish
  myTrail:
    DependsOn:
    - BucketPolicy
    - TopicPolicy
    Type: AWS::CloudTrail::Trail
    Properties:
      S3BucketName:
        Ref: S3Bucket
      SnsTopicName:
        Fn::GetAtt:
        - Topic
        - TopicName
      IsLogging: true
      IsMultiRegionTrail: false
```

From your AWS Cloud9 environment, run the following command:

```
aws cloudformation create-stack --stack-name ccoa-cloudtrail --template-body file:///home/ec2-user/environment/lesson0/ccoa-cloudtrail.yml --parameters ParameterKey=OperatorEmail,ParameterValue=YOUREMAILADDRESS@example.com --capabilities CAPABILITY_NAMED_IAM --disable-rollback --region us-east-2
```

3. Create a new file 

```
touch ccoa-config-recorder.yml
```

4. Paste the contents of the CloudFormation template into `ccoa-config-recorder.yml` and save the file 

```
Description: Setup AWS Config Service
Resources:
  ConfigBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain
    Properties:
      AccessControl: BucketOwnerFullControl
      BucketName: !Sub 'ccoa-awsconfig-${AWS::StackName}-${AWS::AccountId}'
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
      DisplayName: !Sub 'ccoa-${AWS::StackName}-sns-topic'
      TopicName: !Sub 'ccoa-${AWS::StackName}-sns-topic'
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
      Name: !Sub 'ccoa-${AWS::StackName}'
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
aws cloudformation create-stack --stack-name ccoa-config-recorder --template-body file:///home/ec2-user/environment/lesson0/ccoa-config-recorder.yml --capabilities CAPABILITY_NAMED_IAM --disable-rollback --region us-east-2
```

### Check CloudFormation stack status

```
aws cloudformation describe-stacks --stack-name ccoa-config-recorder
```

or, go to [CloudFormation console](https://console.aws.amazon.com/cloudformation/)


## Create a Config Rule

1. Change directory: 

```
cd ~/environment/lesson0
```

2. Create a new file

```
touch ccoa-configrule.yml
```

3. Paste contents


```
---
Resources:
  AWSConfigRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName:
        Ref: ConfigRuleName
      Description: Checks that your Amazon S3 buckets do not allow public write access.
        The rule checks the Block Public Access settings, the bucket policy, and the
        bucket access control list (ACL).
      InputParameters: {}
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_WRITE_PROHIBITED
      MaximumExecutionFrequency:
        Ref: MaximumExecutionFrequency
  AutoRemediationEventRule:
    Type: 'AWS::Events::Rule'
    Properties:
      Name:
        Ref: AWS::StackName
      Description: 'auto remediation rule for config rule: s3-bucket-public-write-prohibited'
      State: ENABLED
      EventPattern:
        source:
          - aws.config
        detail:
          requestParameters:
            evaluations:
              complianceType:
                - NON_COMPLIANT
        additionalEventData:
          managedRuleIdentifier:
            - S3_BUCKET_PUBLIC_WRITE_PROHIBITED
      Targets:
        - Arn: !Sub '${LambdaArn}'
          Id: !Sub '${LambdaId}'
  AutoRemediationIamRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
        - Effect: Allow
          Principal:
            Service:
            - lambda.amazonaws.com
          Action:
          - sts:AssumeRole
      Path: "/"
      Policies:
      - PolicyName: lambda-policy
        PolicyDocument:
          Statement:
          - Effect: Allow
            Action: "*"
            Resource: "*"
          Version: '2012-10-17'
Parameters:
  ConfigRuleName:
    Type: String
    Default: s3-bucket-public-write-prohibited
    Description: The name that you assign to the AWS Config rule.
    MinLength: '1'
    ConstraintDescription: This parameter is required.
  LambdaArn:
    Type: String
    Description: The Arn for an existing Lambda function
    MinLength: '1'
    ConstraintDescription: This parameter is required.
  LambdaId:
    Type: String
    Description: The Id for an existing Lambda function
    MinLength: '1'
    ConstraintDescription: This parameter is required.
  MaximumExecutionFrequency:
    Type: String
    Default: TwentyFour_Hours
    Description: The frequency that you want AWS Config to run evaluations for the
      rule.
    MinLength: '1'
    ConstraintDescription: This parameter is required.
    AllowedValues:
    - One_Hour
    - Three_Hours
    - Six_Hours
    - Twelve_Hours
    - TwentyFour_Hours
```

4. From your AWS Cloud9 environment, run the following command:

```
aws cloudformation create-stack --stack-name ccoa-config-rule --template-body file:///home/ec2-user/environment/lesson0/ccoa-config-rule.yml --parameters ParameterKey=LambdaArn,ParameterValue=LAMBDAARN ParameterKey=LambdaId,ParameterValue=LAMBDAID --capabilities CAPABILITY_NAMED_IAM --disable-rollback --region us-east-2
```

5. Manually edit the CloudWatch Events Rule and Save (Not sure why yet!)
6. Run Config Rule
7. Check S3 bucket
8. Run Config Rule again


## Create a CloudWatch Events Rule

1. Change directory: 

```
cd ~/environment/lesson0
```

2. Create a new file

```
touch ccoa-cwe-rule.yml
```

3. Paste contents


```
```


# Create a Lambda Function that Auto Remediates S3 Bucket using CloudFormation

1. Zip the files and upload to S3
```
aws s3 ls
aws s3 rb s3://ccoa-rem-awsconfig --region REGIONCODE --force
aws s3 rb s3://PIPELINEBUCKET --region REGIONCODE --force
aws s3 rb s3://ARTIFACTBUCKET --region REGIONCODE --force
aws s3 rb s3://$(aws sts get-caller-identity --output text --query 'Account')-pmd-rem-awsconfig --region REGIONCODE --force
aws cloudformation delete-stack --stack-name ccoa-rem-$(aws configure get region --output text) --region REGIONCODE
aws cloudformation delete-stack --stack-name ccoa-rem --region REGIONCODE


sudo rm -rf ~/environment/tmp
mkdir ~/environment/tmp
cd ~/environment/tmp
mkdir codecommit
cd ~/environment/aws-compliance-workshop/lesson0-setup
zip ccoa-lesson0-examples.zip *.*
mv ccoa-lesson0-examples.zip ~/environment/tmp/codecommit
aws s3 sync ~/environment/tmp/codecommit/ s3://pmd-compliance-workshop
```

4. Launch the CloudFormation stack for Config Rules, CWE, and Pipeline

```
aws cloudformation create-stack --stack-name ccoa-rem --template-body file:///home/ec2-user/environment/aws-compliance-workshop/lesson0-setup/ccoa-remediation-pipeline.yml --parameters ParameterKey=EmailAddress,ParameterValue=EMAILADDRESS@example.com ParameterKey=CodeCommitS3Bucket,ParameterValue=pmd-compliance-workshop ParameterKey=CodeCommitS3Key,ParameterValue=ccoa-lesson0-examples.zip --capabilities CAPABILITY_NAMED_IAM --disable-rollback --region REGIONCODE
````

# Autoremediate from the AWS Console

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


## Create an AWS Config Recorder
NOTE: If you've already enabled Config on your AWS account, you do not need to go through these instructions
1. Go to the [Config](https://console.aws.amazon.com/config/) console
2. If it's your first time using Config, click the **Get Started** button
3. Select the **Include global resources (e.g., AWS IAM resources)** checkbox
4. In the *Amazon SNS topic* section, select the **Stream configuration changes and notifications to an Amazon SNS topic.** checkbox
5. Choose the **Create a topic** radio button in the *Amazon SNS topic* section
6. In the *Amazon S3 bucket* section, select the **Create a bucket** radio button
8. In the *AWS Config role* section, select the **Use an existing AWS Config service-linked role** radio button
9. Click the **Next** button
10. Click the **Skip** button on the *AWS Config rules* page
11. Click the **Confirm** button on the *Review* page

NOTE: This creates a Config Delivery Channel

## Create an S3 Bucket in violation
`ccoa-s3-write-violation-ACCOUNTID`
1. Go to the [S3](https://console.aws.amazon.com/s3/) console
2. Click the **Create bucket** button
3. Enter `ccoa-s3-write-violation-ACCOUNTID` in the **Bucket name** field (replacing `ACCOUNTID` with your account id)
4. Click **Next** on the *Configure Options* screen
5. Unselect the **Block all public access** checkbox and click **Next** on the *Set Permissions* screen
6. Click **Create bucket** on the *Review* screen
7. Select the `ccoa-s3-write-violation-ACCOUNTID` bucket and choose the **Permissions** tab
8. Click on **Bucket Policy** and paste the contents from below into the *Bucket policy editor* text area (replace both `mybucketname` values with the `ccoa-s3-write-violation-ACCOUNTID` bucket you just created)
9. Click the **Save** button

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

You'll receive this message: *You have provided public access to this bucket. We highly recommend that you never grant any kind of public access to your S3 bucket.*

## Create an IAM Policy and Role for Lambda
`ccoa-s3-write-policy`
1. Go to the [IAM](https://console.aws.amazon.com/iam/) console
2. Click on **Policies**
3. Click **Create policy**
4. Click the **JSON** tab
5. Copy and **replace** the contents below into the **JSON** text area
6. Click the **Review policy** button
7. Enter **ccoa-s3-write-policy** in the **Name* field
8. Click the **Create policy** button

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
9. Click on **Roles**
10. Click the **Create role** button
11. Click **Lambda** from the *Choose the service that will use this role* section
12. Click the **Next: Permissions** button
13. Click **ccoa-s3-write-policy** in the *Filter policies* search field
14. Select the checkbox next to **ccoa-s3-write-policy** and click on the **Next: Tags** button
15. Click the **Next: Review** button
16. Enter `ccoa-s3-write-role` in the **Role name** field
17. Click the **Create role** button

## Create a Lambda function
`ccoa-s3-write-remediation`
1. Go to the [Lambda](https://console.aws.amazon.com/lambda/) console
2. Click the **Create function** button
3. Keep the *Author from scratch* radio button selected and enter `ccoa-s3-write-remediation` in the *Function name* field
4. Choose `Node.js 10.x` for the **Runtime**
5. Under *Permissions* choose the **Choose or create an execution role**
6. Under **Execution role**, choose **Use an existing role**
7. In the **Existing role** dropdown, choose `ccoa-s3-write-role`
8. Click the **Create function** button
9. Scroll to the *Function code* section and within the `index.js` pane, copy and **replace** the code from below


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
10. Click the **Save** button


## Create a Config Rule (Managed Rule which runs Lambda function)
`ccoa-s3-write-rule`
1. Go to the [Config](https://console.aws.amazon.com/config/) console
2. Click **Rules**
3. Click the **Add rule** button
4. In the *filter* box, type `s3-bucket-public-write-prohibited`
5. Choose the **s3-bucket-public-write-prohibited** rule
6. Click on the **Remediation action** dropdown within the *Choose remediation action* section
7. Choose the **AWS-PublishSNSNotification** remediation in the dropdown
8. Click **Yes** in the *Auto remediation* field
9. In the **Parameters** field, enter `arn:aws:iam::123456789012:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM` in the **AutomationAssumeRole** field (replacing `123456789012` with your AWS account id)
10. In the **Parameters** field, enter `s3-bucket-public-write-prohibited violated` in the **Message** field
11. In the **Parameters** field, enter `arn:aws:sns:us-east-1:123456789012:ccoa-awsconfig-123456789012` in the **TopicArn** field (replacing `123456789012` with your AWS account id)
12. Click the **Save** button

## Cloudwatch Event Rule
`ccoa-s3-write-cwe`
1. Go to the [CloudWatch](https://console.aws.amazon.com/cloudwatch/) console
2. Click on **Rules**
3. Click the **Create rule** button
4. Choose **Event pattern** in the *Event Source* section
4. In the *Event Pattern Preview* section, click **Edit**
5. Copy the contents from below and **replace** in the *Event pattern* text area
6. Click the **Save** button
7. Click the **Add target** button
8. Choose **Lambda function**
9. Select the `ccoa-s3-write-remediation` function you'd previously created.
10. Click the **Configure details** button
11. Enter `ccoa-s3-write-cwe` in the **Name** field
12. Click the **Create rule** button


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

## View Config Rules
1. Go to the [Config](https://console.aws.amazon.com/config/) console
2. Click on **Rules**
3. Select the **s3-bucket-public-write-prohibited** rule
4. Click the **Re-evaluate** button
5. Go back **Rules** in the [Config](https://console.aws.amazon.com/config/) console
6. Go to the [S3](https://console.aws.amazon.com/s3/) console and choose the `ccoa-s3-write-violation-ACCOUNTID` bucket that the bucket policy has been removed. 
7. Go back **Rules** in the [Config](https://console.aws.amazon.com/config/) console and confirm that the **s3-bucket-public-write-prohibited** rule is **Compliant** 

==================================================

# AWS Chatbot

![AWS Chatbot](https://github.com/PaulDuvall/aws-compliance-workshop/wiki/img/remediation/remediation-aws-chatbot.png
)

## Create an Amazon SNS Topic
1. Go to the [Simple Notification Service](https://console.aws.amazon.com/sns/) console.
2. Select **Topics**
3. Click **Create topic**
4. Enter `ccoa-chatbot-topic` in the **Name** and **Display name** fields
5. Click the **Create topic** button

## Create an IAM Policy and Role for Chatbot

1. Go to the [IAM](https://console.aws.amazon.com/iam/) console
2. Click on **Policies**
3. Click **Create policy**
4. Click the **JSON** tab
5. Copy and **replace** the contents below into the **JSON** text area
6. Click the **Review policy** button
7. Enter **ccoa-chatbot-policy** in the **Name* field
8. Click the **Create policy** button

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "chatbot:*",
                "cloudwatch:*",
                "config:*",
                "iam:*",
                "lambda:*",
                "logs:*",
                "s3:*",
                "sns:*"
            ],
            "Resource": "*"
        }
    ]
}

```

9. Click on **Roles**
10. Click the **Create role** button
11. Click **Lambda** from the *Choose the service that will use this role* section
12. Click the **Next: Permissions** button
13. Click **ccoa-chatbot-policy** in the *Filter policies* search field
14. Select the checkbox next to **ccoa-chatbot-policy** and click on the **Next: Tags** button
15. Click the **Next: Review** button
16. Enter `ccoa-chatbot-role` in the **Role name** field
17. Click the **Create role** button


## Create a Lambda function for Chatbot

1. Go to the [Lambda](https://console.aws.amazon.com/lambda/) console
2. Click the **Create function** button
3. Keep the *Author from scratch* radio button selected and enter `ccoa-chatbot-remediation` in the *Function name* field
4. Choose `Node.js 10.x` for the **Runtime**
5. Under *Permissions* choose the **Choose or create an execution role**
6. Under **Execution role**, choose **Use an existing role**
7. In the **Existing role** dropdown, choose `ccoa-chatbot-role`
8. Click the **Create function** button
9. Scroll to the *Function code* section and within the `index.js` pane, copy and **replace** the code from below


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

## Create an S3 Bucket in violation for Chatbot

1. Go to the [S3](https://console.aws.amazon.com/s3/) console
2. Click the **Create bucket** button
3. Enter `ccoa-s3-violation-chatbot-ACCOUNTID` in the **Bucket name** field (replacing `ACCOUNTID` with your account id)
4. Click **Next** on the *Configure Options* screen
5. Unselect the **Block all public access** checkbox and click **Next** on the *Set Permissions* screen
6. Click **Create bucket** on the *Review* screen
7. Select the `ccoa-s3-violation-chatbot-ACCOUNTID` bucket and choose the **Permissions** tab
8. Click on **Bucket Policy** and paste the contents from below into the *Bucket policy editor* text area (replace both `mybucketname` values with the `ccoa-s3-write-violation-ACCOUNTID` bucket you just created)
9. Click the **Save** button

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

## Create a Config Rule for Chatbot
1. Go to the [Config](https://console.aws.amazon.com/config/) console
2. Click **Rules**
3. Click the **Add rule** button
4. In the *filter* box, type `s3-bucket-public-write-prohibited`
5. Choose the **s3-bucket-public-write-prohibited** rule
6. Click on the **Remediation action** dropdown within the *Choose remediation action* section
7. Choose the **AWS-PublishSNSNotification** remediation in the dropdown
8. Click **Yes** in the *Auto remediation* field
9. In the **Parameters** field, enter `arn:aws:iam::ACCOUNTID:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM` in the **AutomationAssumeRole** field (replacing `ACCOUNTID` with your AWS account id)
10. In the **Parameters** field, enter `s3-bucket-public-write-prohibited violated` in the **Message** field
11. In the **Parameters** field, enter `arn:aws:sns:us-east-1:ACCOUNTID:ccoa-awsconfig-ACCOUNTID` in the **TopicArn** field (replacing `ACCOUNTID` with your AWS account id)
12. Click the **Save** button


## CloudWatch Events Rule Event Pattern for Chatbot

1. Go to the [CloudWatch](https://console.aws.amazon.com/cloudwatch/) console
2. Click on **Rules**
3. Click the **Create rule** button
4. Choose **Event pattern** in the *Event Source* section
4. In the *Event Pattern Preview* section, click **Edit**
5. Copy the contents from below and **replace** in the *Event pattern* text area
6. Click the **Save** button
7. Click the **Add target** button
8. Choose **Lambda function**
9. Select the `ccoa-chatbot-remediation` function you'd previously created.
10. Click the **Configure details** button
11. Enter `ccoa-chatbot-cwe` in the **Name** field
12. Click the **Create rule** button


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

## View Config Rules
1. Go to the [Config](https://console.aws.amazon.com/config/) console
2. Click on **Rules**
3. Select the **s3-bucket-public-write-prohibited** rule
4. Click the **Re-evaluate** button
5. Go back **Rules** in the [Config](https://console.aws.amazon.com/config/) console
6. Go to the [S3](https://console.aws.amazon.com/s3/) console and choose the `ccoa-chatbot-ACCOUNTID` bucket that the bucket policy has been removed. 
7. Go back **Rules** in the [Config](https://console.aws.amazon.com/config/) console and confirm that the **s3-bucket-public-write-prohibited** rule is **Compliant** 

## AWS Chatbot - Configure client (select Slack) - using SNS Topic and IAM Role

1. Go to the [Chatbot](https://console.aws.amazon.com/chatbot/) console
2. From the *Configure new client* page, click on **Slack** and click the **Configure** button
3. Click the **Allow** button on the *On <<Slack workspace>>, AWS Chatbot (Beta) would like to* page
4. Select the **Channel type** and name
5. In the **IAM permissions** section, choose the IAM role you previously created.
6. Choose **SNS Region** and the **SNS topics** (choosing the region and topic you previously created) in the *SNS topics* section
7. Click the **Configure** button

https://us-east-2.console.aws.amazon.com/chatbot/
https://console.aws.amazon.com/sns/
https://console.aws.amazon.com/lambda/
https://console.aws.amazon.com/cloudwatch/
https://console.aws.amazon.com/iam/
https://docs.aws.amazon.com/config/latest/developerguide/monitor-config-with-cloudwatchevents.html

### Notes

* https://aws.amazon.com/chatbot/
* https://aws.amazon.com/blogs/devops/introducing-aws-chatbot-chatops-for-aws/

The identity provider(s) cloudwatch.amazonaws.com  
CloudWatchFullAccess
CloudWatchEventsFullAccess 

#### Create an IAM Role

1. Go to the [IAM](https://console.aws.amazon.com/iam/) console
2. Click on **Roles**
3. Click the **Create role** button
4. Click **CloudWatch** from the *Choose the service that will use this role* section
5. Click the **Next: Permissions** button
6. Click **CloudWatchFullAccess** in the *Filter policies* search field
7. Select the checkbox next to **CloudWatchFullAccess**
8. Click **CloudWatchEventsFullAccess** in the *Filter policies* search field
9. Select the checkbox next to **CloudWatchFullAccess**
10. Click on the **Next: Tags** button
15. Click the **Next: Review** button
16. Enter `ccoa-chatbot-role` in the **Role name** field
17. Click the **Create role** button


=============================================================

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
      Name: !Sub 'ccoa-${AWS::StackName}'
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

Create a new [Lambda Function](https://console.aws.amazon.com/lambda/) and paste the following Node.js code below and save the function. Name the function `ccoa-s3-write-remediation`

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

[CloudWatch Events Rule](https://console.aws.amazon.com/cloudwatch/). Name it `ccoa-s3-write-cwe`.

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

# Other
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
2. Click the **Create bucket** button
3. Enter `ccoa-config-ACCOUNTID` in the **Bucket name** field (replacing `ACCOUNTID` with your account id)
4. Click **Next** on the *Configure Options* screen
5. Click **Next** on the *Set Permissions* screen
6. Click **Create bucket** on the *Review* screen


