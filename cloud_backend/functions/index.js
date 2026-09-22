/**
 * Firebase Cloud Functions: Fall Alert Push Notification Dispatcher
 * ===================================================================
 * Automatically triggered when a new fall incident is recorded in Firestore
 * by the ESP32 wearable or the TinyML Fall Detection Pipeline.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onFallIncidentCreated = onDocumentCreated("falls/{fallId}", async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }

  const fallData = snap.data();
  const fallId = event.params.fallId;

  // Extract Clinical Triage & Physics parameters from the pipeline
  const triage = (fallData.triage || "HIGH").toUpperCase();
  const activity = fallData.activity || "UNKNOWN";
  const location = fallData.location || "Home";
  const still = fallData.still === true;
  const fallHeight = fallData.fall_height_m ? Number(fallData.fall_height_m).toFixed(2) : "N/A";
  const peakG = fallData.peak_g ? Number(fallData.peak_g).toFixed(1) : "N/A";
  const fraLevel = fallData.fra_level || "Moderate";
  const sleepStatus = fallData.sleep_status || "";

  // Compose high-priority notification title and body
  let title = `🚨 [${triage} PRIORITY] ${activity} Fall Alert!`;
  if (triage === "CRITICAL") {
    title = `🚨 CRITICAL EMERGENCY: Unresponsive Fall (${location})`;
  } else if (triage === "WATCH") {
    title = `⚠️ Stumble / Near-Fall Detected (${location})`;
  }

  let body = "";
  if (sleepStatus.includes("SYNCOPE")) {
    body = `Suspected Fainting / Syncope Collapse from rest! Impact: ${peakG}g. Senior is unmoving.`;
  } else {
    body = `${still ? "SENIOR IS UNMOVING!" : "Movement detected."} Height: ${fallHeight}m | Impact: ${peakG}g | Fracture Risk: ${fraLevel}.`;
  }

  // FCM Payload
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      fallId: String(fallId),
      triage: triage,
      activity: activity,
      still: String(still),
      location: location,
      peakG: String(peakG),
      fallHeight: String(fallHeight),
      fraLevel: fraLevel,
      timestamp: fallData.timestamp || new Date().toISOString(),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "fall_alert_channel",
        sound: "default",
        color: triage === "CRITICAL" ? "#DC2626" : "#EA580C",
        priority: "max",
        defaultVibrateTimings: true,
        visibility: "public",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          contentAvailable: true,
        },
      },
    },
    topic: "caregivers", // Broadcast to all paired caregiver devices
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(`[FCM SUCCESS] Emergency alert dispatched to 'caregivers' topic:`, response);
  } catch (error) {
    console.error(`[FCM ERROR] Failed to send push notification:`, error);
  }
});
