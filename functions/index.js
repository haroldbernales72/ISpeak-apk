const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

exports.sendEmergencyAlert = onDocumentCreated(
  "incidents/{incidentId}",
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.log("No incident data found.");
      return;
    }

    const incident = snapshot.data();

    // Only send notifications for Emergency Quick Alerts.
    if (incident.category !== "Emergency") {
      console.log("Not an emergency incident.");
      return;
    }

    console.log("Emergency alert detected.");

    // Get admin and security users who have an FCM token.
    const usersSnapshot = await db
      .collection("users")
      .where("role", "in", ["admin", "security"])
      .get();

    const tokens = [];

    usersSnapshot.forEach((doc) => {
      const userData = doc.data();

      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    });

    if (tokens.length === 0) {
      console.log("No admin/security FCM tokens found.");
      return;
    }

    const message = {
      notification: {
        title: "🚨 ISpeak Emergency Alert",
        body: "An emergency Quick Alert has been reported on campus.",
      },
      data: {
        incidentId: incident.id || snapshot.id,
        category: incident.category || "Emergency",
        location: incident.location || "School Campus",
        status: incident.status || "New",
      },
      tokens: tokens,
    };

    const response = await getMessaging().sendEachForMulticast(message);

    console.log(
      `Notification sent. Success: ${response.successCount}, Failed: ${response.failureCount}`
    );
  }
);