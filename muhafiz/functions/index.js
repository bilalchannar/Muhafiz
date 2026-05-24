const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Trigger: on create of a notification_logs document.
 * Expects fields: title, body, status ('pending'), targetTrusteeIds (optional array), trusteeTokens (optional array)
 * If trusteeTokens present, uses them; otherwise looks up trustees by id and reads `fcmToken`.
 */
exports.sendNotificationOnCreate = functions.firestore
  .document('notification_logs/{logId}')
  .onCreate(async (snap, ctx) => {
    const data = snap.data();
    if (!data) return null;
    if (data.status && data.status !== 'pending') return null;

    const title = data.title || data.notification?.title || 'Alert';
    const body = data.body || data.notification?.body || '';

    let tokens = [];
    if (Array.isArray(data.trusteeTokens) && data.trusteeTokens.length) {
      tokens = data.trusteeTokens.filter(Boolean);
    } else if (Array.isArray(data.targetTrusteeIds) && data.targetTrusteeIds.length) {
      const promises = data.targetTrusteeIds.map(id =>
        admin.firestore().collection('trustees').doc(id).get().then(d => d.exists ? d.data().fcmToken : null).catch(() => null)
      );
      const results = await Promise.all(promises);
      tokens = results.filter(Boolean);
    }

    if (!tokens.length) {
      await snap.ref.update({ status: 'no_tokens', deliveredAt: admin.firestore.FieldValue.serverTimestamp() });
      return null;
    }

    const message = {
      notification: { title, body },
      tokens,
    };

    try {
      const resp = await admin.messaging().sendMulticast(message);
      const summary = { successCount: resp.successCount, failureCount: resp.failureCount };
      await snap.ref.update({ status: 'sent', deliveredAt: admin.firestore.FieldValue.serverTimestamp(), sendSummary: summary });
    } catch (err) {
      await snap.ref.update({ status: 'failed', error: (err && err.message) ? err.message : String(err), attemptedAt: admin.firestore.FieldValue.serverTimestamp() });
    }

    return null;
  });
