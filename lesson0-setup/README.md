# Setup

https://docs.aws.amazon.com/AmazonS3/latest/user-guide/add-bucket-policy.html

## Create an SNS Topic and Subscription

```
TBD
```

## Configure AWS Config Settings (OPTIONAL)

```
TBD
```


## Create an S3 Bucket

```
aws s3 mb s3://mybucket --region us-east-1
```

### Create an S3 Bucket Policy and assign to Bucket

**CAREFUL: This gives public write access to `mybucketname`. This is for demonstration purposes and AWS highly recommends that you never grant any kind of public access to your S3 bucket.**

1. Create a new file called `policy.json`.

```
cd ~/environment
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

3. Apply the S3 Bucket Policy to the Bucket by running the command below (changing `MyBucket` to the bucket you created in an earlier step).

```
aws s3api put-bucket-policy --bucket MyBucket --policy file://policy.json
```

## Create an AWS Config Rule

```

s3-bucket-public-write-prohibited
S3_BUCKET_PUBLIC_WRITE_PROHIBITED

AutomationAssumeRole

arn:aws:iam::123456789012:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM

arn:aws:sns:us-east-1:123456789012:SNSTopicName

AWS-PublishSNSNotification
```

## Create a Lambda Role

```
TBD
```

## Create a Lambda Function

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

