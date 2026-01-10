# Troubleshooting: Satellite Simulator Lambda Not Triggering

## Problem

The satellite simulator Lambda (`GS-SatelliteSimulator`) was not being triggered when files were uploaded to the uplink S3 bucket. The demo script would hang at "Checking downlink bucket..." because no downlink data was generated.

## Symptoms

- `demo.sh` executed Step 3 (Uplink) successfully but failed to produce data for Step 4 (Downlink).
- CloudWatch logs for `GS-SatelliteSimulator` were empty or non-existent (`The specified log group does not exist`).
- `aws lambda list-functions` showed only `GS-TaskScheduler` was deployed; `GS-SatelliteSimulator` and `GS-GroundReceiver` were missing.

## Root Cause

The Lambda functions `GS-SatelliteSimulator` and `GS-GroundReceiver` failed to deploy during the initial setup, likely due to IAM role propagation delays or script interruption/misconfiguration. As a result, there was no function for the S3 bucket to trigger.

## Fix Steps

### 1. Verify Deployment Status

Checked which functions were actually deployed:

```bash
aws lambda list-functions --region us-west-2 --query 'Functions[?starts_with(FunctionName, `GS-`)].FunctionName'
```

_Result: Only `GS-TaskScheduler` was found._

### 2. Manual Redeployment

Manually deployed the missing functions using the existing role and configuration:

**Environment Variables:**

- Region: `us-west-2`
- Role: `arn:aws:iam::975049932999:role/GroundStationSimRole`

**Deploy Satellite Simulator:**

```bash
zip -q satellite_simulator.zip satellite_simulator.py
aws lambda create-function \
  --function-name GS-SatelliteSimulator \
  --runtime python3.9 \
  --role arn:aws:iam::975049932999:role/GroundStationSimRole \
  --handler satellite_simulator.lambda_handler \
  --zip-file fileb://satellite_simulator.zip \
  --timeout 120 \
  --environment "Variables={DOWNLINK_BUCKET=gs-downlink-975049932999}" \
  --region us-west-2
```

**Deploy Ground Receiver:**

```bash
zip -q ground_receiver.zip ground_receiver.py
aws lambda create-function \
  --function-name GS-GroundReceiver \
  --runtime python3.9 \
  --role arn:aws:iam::975049932999:role/GroundStationSimRole \
  --handler ground_receiver.lambda_handler \
  --zip-file fileb://ground_receiver.zip \
  --timeout 60 \
  --environment "Variables={STORAGE_BUCKET=gs-storage-975049932999,KINESIS_STREAM=gs-telemetry}" \
  --region us-west-2
```

### 3. Reconfigure Triggers

Ran the existing setup script to establish S3 event permissions and notifications (since the previous attempt failed due to missing Lambdas):

```bash
./setup-triggers.sh
```

### 4. Verification

Ran the demo script `demo.sh` again. Confirmed success by:

- Checking CloudWatch logs: `aws logs tail /aws/lambda/GS-SatelliteSimulator ...` -> Verified "Satellite received" logs.
- Checking Downlink Bucket: `aws s3 ls s3://gs-downlink-975049932999/data/ --recursive` -> Verified generated `image.png` and `satellite_data.json`.

## Conclusion

The issue was resolved by identifying that 2 out of 3 Lambda functions were missing, manually redeploying them, and then re-running the trigger setup script.
