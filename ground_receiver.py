"""
Ground Receiver Lambda Function.

This module provides the handler for processing satellite downlink data stored in S3.
It extracts mission metadata, relocates files to task-specific mission storage,
and emits telemetry events to a Kinesis stream for downstream processing.

Part of the AWS-SPACE-STATION project.
"""

import json
import boto3
import os
from datetime import datetime
from typing import Any, Dict

# AWS Service Clients
s3 = boto3.client('s3')
kinesis = boto3.client('kinesis')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler for S3-triggered satellite data ingestion.

    Args:
        event (Dict[str, Any]): Standard S3 event notification object.
        context (Any): AWS Lambda context object.

    Returns:
        Dict[str, Any]: A dictionary containing the HTTP status code.

    Environment Variables:
        STORAGE_BUCKET: The destination S3 bucket for mission-ready data.
        KINESIS_STREAM: The Amazon Kinesis stream name for telemetry events.
    """
    storage_bucket = os.environ['STORAGE_BUCKET']
    stream_name = os.environ['KINESIS_STREAM']
    
    for record in event['Records']:
        # Extract source metadata from S3 event
        source_bucket = record['s3']['bucket']['name']
        source_key = record['s3']['object']['key']
        
        # Parse Task ID and filename from S3 key format: data/<task_id>/<filename>
        parts = source_key.split('/')
        if len(parts) >= 3:
            task_id = parts[1]
            filename = parts[-1]
        else:
            # Skip invalid key structures
            continue
        
        print(f"📡 Ground station received: {filename} for {task_id}")
        
        # Prepare for server-side S3 copy
        copy_source = {'Bucket': source_bucket, 'Key': source_key}
        dest_key = f"missions/{task_id}/{filename}"
        
        # Copy file to mission-specific storage
        s3.copy_object(
            CopySource=copy_source,
            Bucket=storage_bucket,
            Key=dest_key
        )
        
        # Prepare telemetry event payload
        event_data = {
            "event_type": "data_received",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "task_id": task_id,
            "filename": filename,
            "storage_location": f"s3://{storage_bucket}/{dest_key}",
            "size_bytes": record['s3']['object']['size']
        }
        
        # Emit event to Kinesis Data Stream for real-time tracking
        kinesis.put_record(
            StreamName=stream_name,
            Data=json.dumps(event_data),
            PartitionKey=task_id
        )
        
        print(f"✅ Stored and event emitted: {filename}")
    
    return {'statusCode': 200}
