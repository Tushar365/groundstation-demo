#!/bin/bash
set -e

REGION=$(cat config.json | grep region | cut -d'"' -f4)
ACCOUNT_ID=$(cat config.json | grep account_id | cut -d'"' -f4)
UPLINK_BUCKET=$(cat config.json | grep uplink_bucket | cut -d'"' -f4)
DOWNLINK_BUCKET=$(cat config.json | grep downlink_bucket | cut -d'"' -f4)

echo "⚡ Configuring S3 event triggers..."

# Add Lambda permissions
aws lambda add-permission \
  --function-name GS-SatelliteSimulator \
  --statement-id s3-invoke-uplink \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::${UPLINK_BUCKET} \
  --region ${REGION} 2>/dev/null || echo "Permission exists"

aws lambda add-permission \
  --function-name GS-GroundReceiver \
  --statement-id s3-invoke-downlink \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::${DOWNLINK_BUCKET} \
  --region ${REGION} 2>/dev/null || echo "Permission exists"

# Configure uplink bucket notification
cat > uplink-notification.json <<EOOF
{
  "LambdaFunctionConfigurations": [{
    "LambdaFunctionArn": "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:GS-SatelliteSimulator",
    "Events": ["s3:ObjectCreated:*"],
    "Filter": {
      "Key": {
        "FilterRules": [{"Name": "prefix", "Value": "commands/"}]
      }
    }
  }]
}
EOOF

aws s3api put-bucket-notification-configuration \
  --bucket ${UPLINK_BUCKET} \
  --notification-configuration file://uplink-notification.json

# Configure downlink bucket notification
cat > downlink-notification.json <<EOOF
{
  "LambdaFunctionConfigurations": [{
    "LambdaFunctionArn": "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:GS-GroundReceiver",
    "Events": ["s3:ObjectCreated:*"],
    "Filter": {
      "Key": {
        "FilterRules": [{"Name": "prefix", "Value": "data/"}]
      }
    }
  }]
}
EOOF

aws s3api put-bucket-notification-configuration \
  --bucket ${DOWNLINK_BUCKET} \
  --notification-configuration file://downlink-notification.json

echo "✅ S3 triggers configured!"
