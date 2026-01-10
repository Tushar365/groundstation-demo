# Uplink Guide

This document explains how to send commands to the Satellite Simulator using the updated logic that accepts custom locations and timestamps.

## Command File Format

Create a JSON file (e.g., `command.json`) with the following structure:

```json
{
  "task_id": "YOUR-TASK-ID-001",
  "timestamp": "2026-05-20T10:00:00Z",
  "command": "CAPTURE_IMAGE",
  "target_location": {
    "latitude": 40.7128,
    "longitude": -74.006,
    "name": "New York"
  },
  "parameters": {
    "resolution": "high",
    "bands": ["visible", "infrared"]
  }
}
```

## How to Uplink

### Option 1: AWS Console

1.  Navigate to **S3** in the AWS Console.
2.  Open your **Uplink Bucket** (e.g., `gs-uplink-<your-account>`).
3.  Go to the `commands/` folder.
4.  **Upload** your JSON file.

### Option 2: AWS CLI

```bash
# Replace with your actual bucket name
aws s3 cp command.json s3://gs-uplink-975049932999/commands/command.json
```

## Verifying the Downlink

After uploading, the satellite simulator will process the command and place the results in the **Downlink Bucket**.

1.  Navigate to your **Downlink Bucket** (e.g., `gs-downlink-<your-account>`).
2.  Look for a folder named `data/YOUR-TASK-ID-001/`.
3.  Open `satellite_data.json` to see the telemetry with your specific coordinates.
