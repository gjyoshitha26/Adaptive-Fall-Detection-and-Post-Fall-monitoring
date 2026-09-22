#!/usr/bin/env python3
"""
Direct Cloud Push Notification Dispatcher (FCM Test Tool)
===========================================================
This script allows you to test sending instant FCM push notifications
directly to the Caregiver Mobile App without needing to deploy
Cloud Functions first.
"""

import sys
import json
import argparse
from datetime import datetime, timezone

try:
    import requests
except ImportError:
    print("Please install requests: pip install requests")
    sys.exit(1)

def send_alert_via_fcm_legacy(server_key, title, body, data=None):
    """
    Send push notification via Firebase FCM Legacy HTTP protocol
    Endpoint: https://fcm.googleapis.com/fcm/send
    """
    url = "https://fcm.googleapis.com/fcm/send"
    headers = {
        "Authorization": f"key={server_key}",
        "Content-Type": "application/json"
    }

    payload = {
        "to": "/topics/caregivers",
        "priority": "high",
        "notification": {
            "title": title,
            "body": body,
            "sound": "default",
            "android_channel_id": "fall_alert_channel"
        },
        "data": data or {}
    }

    try:
        res = requests.post(url, headers=headers, json=payload, timeout=10)
        if res.status_code == 200:
            print("[SUCCESS] Push notification dispatched successfully to '/topics/caregivers'!")
            print(res.text)
            return True
        else:
            print(f"[ERROR] FCM dispatch failed: HTTP {res.status_code} - {res.text}")
            return False
    except Exception as e:
        print(f"[ERROR] Connection failed: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Dispatch Fall Notification to Caregiver App")
    parser.add_argument("--key", help="Firebase Cloud Messaging Server Key (from Project Settings -> Cloud Messaging)")
    parser.add_argument("--triage", default="CRITICAL", choices=["CRITICAL", "HIGH", "WATCH"], help="Triage Priority")
    parser.add_argument("--activity", default="STAIRS", help="Pre-fall activity (e.g., STAIRS, WALK, SLEEP)")
    parser.add_argument("--height", type=float, default=1.12, help="Fall height in meters")
    parser.add_argument("--impact", type=float, default=4.2, help="Peak acceleration in g")
    parser.add_argument("--still", action="store_true", default=True, help="Person is still/unresponsive")
    args = parser.parse_args()

    title = f"🚨 [{args.triage} PRIORITY] {args.activity} Fall Alert!"
    body = f"{'PERSON UNRESPONSIVE' if args.still else 'Movement detected'} | Height: {args.height:.2f}m | Impact: {args.impact:.1f}g"

    data = {
        "triage": args.triage,
        "activity": args.activity,
        "fall_height_m": str(args.height),
        "peak_g": str(args.impact),
        "still": str(args.still),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

    print("=" * 60)
    print("Caregiver Push Notification Dispatcher")
    print(f"Title: {title}")
    print(f"Body:  {body}")
    print(f"Data:  {json.dumps(data, indent=2)}")
    print("=" * 60)

    if not args.key:
        print("\nNote: Provide --key <SERVER_KEY> from Firebase Console to send over the air.")
        return

    send_alert_via_fcm_legacy(args.key, title, body, data)

if __name__ == "__main__":
    main()
