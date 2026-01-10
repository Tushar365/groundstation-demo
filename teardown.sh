#!/bin/bash
set -e

REGION=$(cat config.json | grep region | cut -d'"' -f4)
UPLINK_BUCKET=$(cat config.json | grep uplink_bucket | cut -d'"' -f4)
DOWNLINK_BUCKET=$(cat config.json | grep downlink_bucket | cut -d'"' -f4)
STORAGE_BUCKET=$(cat config.json | grep storage_bucket | cut -d'"' -f4)
KINESIS_STREAM=$(cat config.json | grep kinesis_stream | cut -d'"' -f4)
ROLE_NAME=$(cat config.json | grep role_name | cut -d'"' -f4)

echo "🗑️  Cleaning up resources..."

# Delete S3 buckets
for bucket in ${UPLINK_BUCKET} ${DOWNLINK_BUCKET} ${STORAGE_BUCKET}; do
    echo "Deleting bucket: ${bucket}"
    aws s3 rm s3://${bucket} --recursive 2>/dev/null || true
    aws s3 rb s3://${bucket} 2>/dev/null || true
done

# Delete Lambda functions
for func in GS-TaskScheduler GS-SatelliteSimulator GS-GroundReceiver; do
    echo "Deleting function: ${func}"
    aws lambda delete-function --function-name ${func} --region ${REGION} 2>/dev/null || true
done

# Delete Kinesis stream
echo "Deleting Kinesis stream: ${KINESIS_STREAM}"
aws kinesis delete-stream --stream-name ${KINESIS_STREAM} --region ${REGION} 2>/dev/null || true

# Delete IAM role
echo "Deleting IAM role: ${ROLE_NAME}"
aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role-policy --role-name ${ROLE_NAME} --policy-name GroundStationPolicy 2>/dev/null || true
aws iam delete-role --role-name ${ROLE_NAME} 2>/dev/null || true

echo "✅ Cleanup complete!"
