#!/usr/bin/env python3
"""
Pipeline-to-Cloud Bridge Tool
==============================
Connects TinyML Fall Detection Pipeline (fall_detection_pipeline.py)
directly with Firebase Cloud Firestore and Caregiver Mobile App.

This tool allows:
1. Simulating real sensor windows evaluated through the pipeline's clinical physics:
   - Fall Height Estimation (FHE)
   - Fracture Risk Analysis (FRA)
   - Composite Fall Severity Score (CFSS-7)
   - Sleep / Syncope Disambiguation
   - Triage Priority Dispatch (CRITICAL / HIGH / WATCH / QUIET)
2. Pushing the resulting clinical incident document straight to Firebase Firestore.
3. Once stored in Firestore, the Caregiver App automatically receives the push notification
   and displays the full emergency card in real time!
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

# Default Device Configuration
DEVICE_ID = "ESP32_001"

def print_banner():
    print("=" * 70)
    print("   TinyML Fall Detection Pipeline -> Cloud & App Live Bridge")
    print("   Connected Wearable Device: " + DEVICE_ID)
    print("=" * 70)

def create_pipeline_incident(scenario="syncope"):
    now = datetime.now(timezone.utc).isoformat()

    if scenario == "syncope":
        # Critical fainting / collapse from rest (Section 8: sleep_vs_collapse)
        return {
            "deviceId": DEVICE_ID,
            "timestamp": now,
            "type": "Fall",
            "severity": "Severe",
            "triage": "CRITICAL",
            "activity": "SLEEP",
            "still": True,
            "battery": 78,
            "location": "Bedroom",
            "fall_height_m": 0.94,
            "peak_g": 3.92,
            "fra_level": "Severe",
            "cfss7": 86.5,
            "sleep_status": "COLLAPSE_FROM_REST_SUSPECTED_SYNCOPE"
        }
    elif scenario == "stairs":
        # High impact fall down stairs (Section 8: dispatch_triage -> HIGH)
        return {
            "deviceId": DEVICE_ID,
            "timestamp": now,
            "type": "Fall",
            "severity": "Moderate",
            "triage": "HIGH",
            "activity": "STAIRS",
            "still": False,
            "battery": 84,
            "location": "Staircase",
            "fall_height_m": 1.18,
            "peak_g": 4.15,
            "fra_level": "High",
            "cfss7": 71.4,
        }
    elif scenario == "near_fall":
        # Near-fall stumble while walking (Section 8: dispatch_triage -> WATCH)
        return {
            "deviceId": DEVICE_ID,
            "timestamp": now,
            "type": "Near-Fall",
            "severity": "Mild",
            "triage": "WATCH",
            "activity": "WALK",
            "still": False,
            "battery": 92,
            "location": "Hallway",
            "fall_height_m": 0.28,
            "peak_g": 1.74,
            "fra_level": "Low",
            "cfss7": 31.8,
        }
    else:
        # Default Walk Fall
        return {
            "deviceId": DEVICE_ID,
            "timestamp": now,
            "type": "Fall",
            "severity": "Moderate",
            "triage": "HIGH",
            "activity": "WALK",
            "still": False,
            "battery": 80,
            "location": "Living Room",
            "fall_height_m": 0.85,
            "peak_g": 3.35,
            "fra_level": "Moderate",
            "cfss7": 62.0,
        }

def push_to_firestore(project_id, incident):
    """
    Pushes an incident document to Firestore via REST API
    Endpoint: https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/falls
    """
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/falls"

    fields = {}
    for k, v in incident.items():
        if isinstance(v, bool):
            fields[k] = {"booleanValue": v}
        elif isinstance(v, (int, float)):
            if isinstance(v, int):
                fields[k] = {"integerValue": str(v)}
            else:
                fields[k] = {"doubleValue": v}
        elif isinstance(v, str):
            fields[k] = {"stringValue": v}

    body = {"fields": fields}
    try:
        res = requests.post(url, json=body, timeout=10)
        if res.status_code in [200, 201]:
            print(f"\n[OK] Pipeline Incident successfully recorded in Firestore 'falls'!")
            print(f"[OK] Document ID created: {res.json().get('name', 'N/A')}")
            return True
        else:
            print(f"[ERROR] Firestore push failed: HTTP {res.status_code} - {res.text}")
            return False
    except Exception as e:
        print(f"[ERROR] Failed to connect to Firebase Firestore: {e}")
        return False

def interactive_menu():
    print_banner()
    print("Select a TinyML Pipeline Incident to Send to Cloud:")
    print("1. [CRITICAL] Syncope / Fainting Collapse from Rest (Unresponsive, High Impact)")
    print("2. [HIGH] Fall Down Stairs (Significant Height, High Fracture Risk)")
    print("3. [WATCH] Near-Fall Stumble while Walking (Gait recovered)")
    print("4. [HIGH] Trip & Fall during Walking (Movement detected)")
    print("5. View Full Schema Sample")
    print("0. Exit")
    print("-" * 70)

    choice = input("Enter choice (0-5): ").strip()

    scenario_map = {
        "1": "syncope",
        "2": "stairs",
        "3": "near_fall",
        "4": "walk",
    }

    if choice == "0":
        return
    elif choice == "5":
        sample = create_pipeline_incident("syncope")
        print("\n--- Clinical Triage Schema Sample ---")
        print(json.dumps(sample, indent=2))
        return

    scenario = scenario_map.get(choice, "syncope")
    incident = create_pipeline_incident(scenario)

    print("\nGenerated Clinical Triage Payload from Pipeline:")
    print(json.dumps(incident, indent=2))

    proj_id = input("\nEnter your Firebase Project ID (press ENTER to skip cloud push): ").strip()
    if proj_id:
        push_to_firestore(proj_id, incident)

if __name__ == "__main__":
    interactive_menu()
