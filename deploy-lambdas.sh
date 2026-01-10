#!/bin/bash
set -e

REGION=$(cat config.json | grep region | cut -d'"' -f4)
ROLE_ARN=$(cat config.json | grep role_arn | cut -d'"' -f4)
UPLINK_BUCKET=$(cat config.json | grep uplink_bucket | cut -d'"' -f4)
DOWNLINK_BUCKET=$(cat config.json | grep downlink_bucket | cut -d'"' -f4)
STORAGE_BUCKET=$(cat config.json | grep storage_bucket | cut -d'"' -f4)
KINESIS_STREAM=$(cat config.json | grep kinesis_stream | cut -d'"' -f4)

echo "🚀 Deploying Lambda functions..."

# Deploy Task Scheduler
echo "Deploying Task Scheduler..."
zip -q task_scheduler.zip task_scheduler.py
aws lambda create-function \
  --function-name GS-TaskScheduler \
  --runtime python3.9 \
  --role ${ROLE_ARN} \
  --handler task_scheduler.lambda_handler \
  --zip-file fileb://task_scheduler.zip \
  --timeout 60 \
  --environment "Variables={UPLINK_BUCKET=${UPLINK_BUCKET}}" \
  --region ${REGION} \
  2>/dev/null || aws lambda update-function-code \
  --function-name GS-TaskScheduler \
  --zip-file fileb://task_scheduler.zip \
  --region ${REGION}

# Deploy Satellite Simulator
echo "Deploying Satellite Simulator..."
zip -q satellite_simulator.zip satellite_simulator.py
aws lambda create-function \
  --function-name GS-SatelliteSimulator \
  --runtime python3.9 \
  --role ${ROLE_ARN} \
  --handler satellite_simulator.lambda_handler \
  --zip-file fileb://satellite_simulator.zip \
  --timeout 120 \
  --environment "Variables={DOWNLINK_BUCKET=${DOWNLINK_BUCKET}}" \
  --region ${REGION} \
  2>/dev/null || aws lambda update-function-code \
  --function-name GS-SatelliteSimulator \
  --zip-file fileb://satellite_simulator.zip \
  --region ${REGION}

# Deploy Ground Receiver
echo "Deploying Ground Receiver..."
zip -q ground_receiver.zip ground_receiver.py
aws lambda create-function \
  --function-name GS-GroundReceiver \
  --runtime python3.9 \
  --role ${ROLE_ARN} \
  --handler ground_receiver.lambda_handler \
  --zip-file fileb://ground_receiver.zip \
  --timeout 60 \
  --environment "Variables={STORAGE_BUCKET=${STORAGE_BUCKET},KINESIS_STREAM=${KINESIS_STREAM}}" \
  --region ${REGION} \
  2>/dev/null || aws lambda update-function-code \
  --function-name GS-GroundReceiver \
  --zip-file fileb://ground_receiver.zip \
  --region ${REGION}

echo "✅ Lambda functions deployed!"
