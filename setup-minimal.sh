#!/bin/bash
set -e

REGION=us-west-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)


echo "🚀 Setting up AWS Ground Station Simulation..."
echo "Region: ${REGION}"
echo "Account: ${ACCOUNT_ID}"
echo ""

# Create S3 buckets
echo "📦 Creating S3 buckets..."
UPLINK_BUCKET="gs-uplink-${ACCOUNT_ID}"
DOWNLINK_BUCKET="gs-downlink-${ACCOUNT_ID}"
STORAGE_BUCKET="gs-storage-${ACCOUNT_ID}"

aws s3 mb s3://${UPLINK_BUCKET} --region ${REGION} 2>/dev/null || echo "Uplink bucket exists"
aws s3 mb s3://${DOWNLINK_BUCKET} --region ${REGION} 2>/dev/null || echo "Downlink bucket exists"
aws s3 mb s3://${STORAGE_BUCKET} --region ${REGION} 2>/dev/null || echo "Storage bucket exists"

# Create Kinesis stream
echo "📡 Creating Kinesis stream..."
STREAM_NAME="gs-telemetry"
aws kinesis create-stream \
  --stream-name ${STREAM_NAME} \
  --shard-count 1 \
  --region ${REGION} 2>/dev/null || echo "Stream exists"

echo "Waiting for stream to be active..."
aws kinesis wait stream-exists --stream-name ${STREAM_NAME} --region ${REGION}

# Create IAM role for Lambda
echo "🔐 Creating IAM role..."
ROLE_NAME="GroundStationSimRole"

cat > trust-policy.json <<EOOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOOF

aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document file://trust-policy.json \
  2>/dev/null || echo "Role exists"

aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

cat > lambda-policy.json <<EOOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["kinesis:PutRecord"],
      "Resource": "*"
    }
  ]
}
EOOF

aws iam put-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name GroundStationPolicy \
  --policy-document file://lambda-policy.json

echo "Waiting for IAM role to propagate..."
sleep 10

# Save configuration
cat > config.json <<EOOF
{
  "region": "${REGION}",
  "account_id": "${ACCOUNT_ID}",
  "uplink_bucket": "${UPLINK_BUCKET}",
  "downlink_bucket": "${DOWNLINK_BUCKET}",
  "storage_bucket": "${STORAGE_BUCKET}",
  "kinesis_stream": "${STREAM_NAME}",
  "role_name": "${ROLE_NAME}",
  "role_arn": "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
}
EOOF

echo ""
echo "✅ Infrastructure setup complete!"
echo ""
cat config.json
