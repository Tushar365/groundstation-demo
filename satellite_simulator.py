"""
Satellite Simulator Lambda Function.

This module simulates satellite behavior in response to uplinked commands.
It generates mock telemetry data (battery, temperature, altitude) and 
simulated planetary imagery, then downlinks the results to a designated S3 bucket.

Part of the AWS-SPACE-STATION project.
"""

import json
import boto3
import os
from datetime import datetime
import random
from typing import Any, Dict

# AWS Service Clients
s3 = boto3.client('s3')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler for satellite operation simulation.

    Triggers when a new command is uploaded to the uplink bucket.
    Generates synthetic telemetry and imagery based on the command.

    Args:
        event (Dict[str, Any]): Standard S3 event notification object.
        context (Any): AWS Lambda context object.

    Returns:
        Dict[str, Any]: A dictionary containing the HTTP status code.

    Environment Variables:
        DOWNLINK_BUCKET: The S3 bucket where simulated satellite data is "downlinked".
    """
    downlink_bucket = os.environ['DOWNLINK_BUCKET']
    
    for record in event['Records']:
        # Extract command location from S3 event
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        # Read the uplinked command
        obj = s3.get_object(Bucket=bucket, Key=key)
        command = json.loads(obj['Body'].read().decode('utf-8'))
        
        task_id = command['task_id']
        print(f"🛰️  Satellite received: {task_id}")
        
        # Generate synthetic satellite telemetry and mission metadata
        satellite_data = {
            "task_id": task_id,
            "satellite_id": "SAT-SIM-001",
            "capture_time": datetime.utcnow().isoformat() + "Z",
            "telemetry": {
                "battery_voltage": round(random.uniform(27.5, 28.5), 2),
                "temperature_c": round(random.uniform(-10, 30), 1),
                "altitude_km": round(random.uniform(450, 550), 1),
                "status": "healthy"
            },
            "logs": [
                f"Command received: {command['command']}",
                f"Target: {command['target_location']['name']}",
                "Camera activated",
                "Image captured",
                "Data compressed",
                "Downlink ready"
            ],
            "imagery": {
                "image_id": f"IMG-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
                "resolution_m": 0.5,
                "size_mb": round(random.uniform(50, 150), 1),
                "format": "GeoTIFF",
                "bands": command['parameters']['bands']
            }
        }
        
        # Store metadata in the downlink bucket
        downlink_key = f"data/{task_id}/satellite_data.json"
        s3.put_object(
            Bucket=downlink_bucket,
            Key=downlink_key,
            Body=json.dumps(satellite_data, indent=2),
            ContentType='application/json'
        )
        
        # Generate and store a "dummy" image file to represent captured data
        dummy_image = b'\x89PNG\r\n\x1a\n' + b'\x00' * 1024
        s3.put_object(
            Bucket=downlink_bucket,
            Key=f"data/{task_id}/image.png",
            Body=dummy_image,
            ContentType='image/png'
        )
        
        print(f"✅ Downlink complete: {task_id}")
    
    return {'statusCode': 200}
