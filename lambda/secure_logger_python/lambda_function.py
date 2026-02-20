import json
import logging

logger = logging.getLogger()
logger.setLevel("INFO")

def lambda_handler(event, context):
    # event is already the minimal transformed payload
    # e.g. { "message": "...", "requestId": "..." }
    print(json.dumps(event, ensure_ascii=False, indent=2))
    # If you specifically want to print just the message:
    if "message" in event:
        print(f"Message: {event['message']}")
    return {"status": "ok"}