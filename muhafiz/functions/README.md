# Muhafiz Notification Delivery Cloud Function

This Cloud Function listens for newly-created `notification_logs` documents in Firestore and delivers notifications via Firebase Cloud Messaging (FCM) to trustee device tokens.

Deployment:

1. Install dependencies and deploy from the `functions` folder:

```bash
cd functions
npm install
gcloud functions deploy sendNotificationOnCreate \
  --region=us-central1 \
  --runtime=nodejs18 \
  --trigger-event=providers/cloud.firestore/eventTypes/document.create \
  --trigger-resource="projects/PROJECT_ID/databases/(default)/documents/notification_logs/{logId}" 
```

2. Replace `PROJECT_ID` with your Firebase project ID. Alternatively use the `firebase` CLI:

```bash
cd functions
npm install
firebase deploy --only functions:sendNotificationOnCreate
```

How it works:
- On create of a `notification_logs/{logId}`, the function checks for `trusteeTokens` (array) on the document. If present, it sends to those tokens.
- If `trusteeTokens` is absent but `targetTrusteeIds` is present, the function looks up each trustee in `trustees/{trusteeId}` and reads `fcmToken`.
- The function updates the `notification_logs` doc with `status` ('sent'|'failed'|'no_tokens') and a minimal `sendSummary` or `error`.

Next steps:
- Add a scheduled / retry function to process `pending` logs that failed earlier.
- Harden permissions and add error monitoring.
