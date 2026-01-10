"""
Task Scheduler Lambda Function.

This module is responsible for initiating mission tasks by generating
satellite commands and uploading them to the uplink storage bucket.
It serves as the entry point for simulated satellite operations.

Part of the AWS-SPACE-STATION project.
"""

import json
import boto3
import os
from datetime import datetime
from typing import Any, Dict

# AWS Service Client
s3 = boto3.client('s3')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler for scheduling satellite tasks.

    Creates a structured CAPTURE_IMAGE command and uploads it to S3
    to be picked up by the satellite simulator.

    Args:
        event (Dict[str, Any]): The triggering event (e.g., CloudWatch, API Gateway).
        context (Any): AWS Lambda context object.

    Returns:
        Dict[str, Any]: A dictionary containing status code and execution metadata.

    Environment Variables:
        UPLINK_BUCKET: The S3 bucket where commands are "uplinked" to the satellite.
    """
    uplink_bucket = os.environ['UPLINK_BUCKET']
    
    # Generate a unique Task ID based on current timestamp
    task_id = f"TASK-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"
    
    # Define the mission command structure
    command = {
        "task_id": task_id,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "command": "CAPTURE_IMAGE",
        "target_location": {
            "latitude": 37.7749,
            "longitude": -122.4194,
            "name": "San Francisco"
        },
        "parameters": {
            "resolution": "high",
            "bands": ["visible", "infrared"]
        }
    }
    
    # Upload the command as a JSON object to S3
    key = f"commands/{task_id}.json"
    s3.put_object(
        Bucket=uplink_bucket,
        Key=key,
        Body=json.dumps(command, indent=2),
        ContentType='application/json'
    )
    
    print(f"✅ Command uplinked: {task_id}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'task_id': task_id,
            'status': 'uplinked',
            'location': f's3://{uplink_bucket}/{key}'
        })
    }
