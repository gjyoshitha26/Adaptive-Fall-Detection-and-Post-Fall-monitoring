#!/usr/bin/env python3
"""
ESP32-S3 Wearable Simulator for Caregiver Fall Detection System
================================================================
This script simulates the ESP32-S3 wearable unit sending telemetry
and fall alert events to Firebase (Firestore / Realtime DB).

Use this script during presentations or project demos to trigger:
1. Normal heartbeat / battery updates
2. Severe fall event (Unresponsive / Still)
3. Moderate fall event (Movement detected / Recovered)
4. Mild stumble / trip event
"""

import sys
import time
import json
from datetime import datetime, timezone

try:
    import requests
except ImportError:
    print("Notice: 'requests' package not installed. Run: pip install requests")
    sys.exit(1)

# Default Device Configuration
DEVICE_ID = "ESP32_001"

def print_header():
    print("=" * 60)
    print("   ESP32-S3 Wearable Motion & Fall Detection Simulator")
    print("   Connected Device: " + DEVICE_ID)
    print("=" * 60)

def generate_fall_payload(severity="Severe", still=True, location="Bathroom", battery=78):
    now = datetime.now(timezone.utc).isoformat()
    return {
        "deviceId": DEVICE_ID,
        "timestamp": now,
        "type": "Fall",
        "severity": severity,
        "still": still,
        "battery": battery,
        "location": location
    }

def generate_device_telemetry(status="online", battery=85):
    now = datetime.now(timezone.utc).isoformat()
    return {
        "deviceId": DEVICE_ID,
        "status": status,
        "battery": battery,
        "lastSeen": now
    }

def push_to_firebase_rest(project_id, collection, data):
    """
    Push data via Firestore REST API
    Endpoint: https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{COLLECTION}
    """
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{collection}"
    
    # Format payload into Firestore REST format
    firestore_fields = {}
    for k, v in data.items():
        if isinstance(v, bool):
            firestore_fields[k] = {"booleanValue": v}
        elif isinstance(v, int):
            firestore_fields[k] = {"integerValue": str(v)}
        elif isinstance(v, str):
            firestore_fields[k] = {"stringValue": v}

    body = {"fields": firestore_fields}
    try:
        res = requests.post(url, json=body, timeout=10)
        if res.status_code in [200, 201]:
            print(f"[OK] Event sent to Firebase collection '{collection}'")
            return True
        else:
            print(f"[ERROR] Failed to send: HTTP {res.status_code} - {res.text}")
            return False
    except Exception as e:
        print(f"[ERROR] Connection failed: {e}")
        return False

def interactive_menu():
    print_header()
    print("Select an action:")
    print("1. [Event] Simulate SEVERE Fall (Unresponsive / Still)")
    print("2. [Event] Simulate MODERATE Fall (Movement Detected / Recovered)")
    print("3. [Event] Simulate MILD Stumble")
    print("4. [Telemetry] Send Heartbeat (Online, 84% Battery)")
    print("5. [Telemetry] Send Low Battery Warning (12% Battery)")
    print("6. Show Raw JSON Payloads (for manual Firebase Console entry)")
    print("0. Exit")
    print("-" * 60)

    choice = input("Enter option (0-6): ").strip()

    if choice == '1':
        payload = generate_fall_payload(severity="Severe", still=True, location="Bathroom", battery=74)
        print("\nTriggering Severe Fall Event:")
        print(json.dumps(payload, indent=2))
    elif choice == '2':
        payload = generate_fall_payload(severity="Moderate", still=False, location="Kitchen", battery=78)
        print("\nTriggering Moderate Fall Event:")
        print(json.dumps(payload, indent=2))
    elif choice == '3':
        payload = generate_fall_payload(severity="Mild", still=False, location="Garden", battery=82)
        print("\nTriggering Mild Fall Event:")
        print(json.dumps(payload, indent=2))
    elif choice == '4':
        payload = generate_device_telemetry(status="online", battery=84)
        print("\nSending Online Heartbeat:")
        print(json.dumps(payload, indent=2))
    elif choice == '5':
        payload = generate_device_telemetry(status="online", battery=12)
        print("\nSending Low Battery Heartbeat:")
        print(json.dumps(payload, indent=2))
    elif choice == '6':
        print("\n--- Fall Schema Sample ---")
        print(json.dumps(generate_fall_payload(), indent=2))
        print("\n--- Device Status Schema Sample ---")
        print(json.dumps(generate_device_telemetry(), indent=2))
        return
    else:
        print("Exiting.")
        return

    proj = input("\nEnter Firebase Project ID to send live (press ENTER to skip): ").strip()
    if proj:
        col = "devices" if "status" in payload else "falls"
        push_to_firebase_rest(proj, col, payload)

if __name__ == '__main__':
    interactive_menu()
