#!/bin/bash
set -e

REGION=$(cat config.json | grep region | cut -d'"' -f4)
UPLINK_BUCKET=$(cat config.json | grep uplink_bucket | cut -d'"' -f4)
DOWNLINK_BUCKET=$(cat config.json | grep downlink_bucket | cut -d'"' -f4)
STORAGE_BUCKET=$(cat config.json | grep storage_bucket | cut -d'"' -f4)
KINESIS_STREAM=$(cat config.json | grep kinesis_stream | cut -d'"' -f4)

echo "========================================="
echo "  AWS Ground Station Simulation Demo"
echo "========================================="
echo ""

# Step 1: Trigger satellite task
echo "1️⃣  Scheduling satellite task (uplink)..."
aws lambda invoke \
  --function-name GS-TaskScheduler \
  --region ${REGION} \
  --payload '{}' \
  response.json > /dev/null

TASK_ID=$(cat response.json | grep task_id | cut -d'"' -f4)
echo "   ✅ Task scheduled: ${TASK_ID}"

echo ""
echo "2️⃣  Waiting for satellite processing (15 seconds)..."
sleep 15

echo ""
echo "3️⃣  Checking uplink bucket..."
aws s3 ls s3://${UPLINK_BUCKET}/commands/ --recursive | tail -1

echo ""
echo "4️⃣  Checking downlink bucket..."
aws s3 ls s3://${DOWNLINK_BUCKET}/data/${TASK_ID}/

echo ""
echo "5️⃣  Checking final storage..."
aws s3 ls s3://${STORAGE_BUCKET}/missions/${TASK_ID}/

echo ""
echo "6️⃣  Reading satellite telemetry..."
aws s3 cp s3://${STORAGE_BUCKET}/missions/${TASK_ID}/satellite_data.json - 2>/dev/null | python3 -m json.tool | grep -A 5 telemetry || echo "Still processing..."

echo ""
echo "========================================="
echo "  ✅ Demo Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  • Command uplinked: s3://${UPLINK_BUCKET}/commands/${TASK_ID}.json"
echo "  • Data downlinked: s3://${DOWNLINK_BUCKET}/data/${TASK_ID}/"
echo "  • Final storage: s3://${STORAGE_BUCKET}/missions/${TASK_ID}/"
echo "  • Kinesis stream: ${KINESIS_STREAM}"
