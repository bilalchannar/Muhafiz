# Muhafiz WhatsApp Bot

## Render Free Deployment

This bot uses `whatsapp-web.js` with `RemoteAuth` when `MONGODB_URI` is set, so the WhatsApp login is stored in MongoDB Atlas and reused after restarts or redeploys.

1. Create a free MongoDB Atlas cluster.
2. Add `MONGODB_URI` in your Render service environment variables.
3. Keep `SESSION_ID=main-whatsapp-session` so the same bot session is reused.
4. Deploy or restart the service.
5. Open the `/qr` route and scan the QR code once.
6. Restart the service to confirm the session is reused automatically.

Example `MONGODB_URI` format:

mongodb://bilaltariq:<db_password>@ac-z9ebeqz-shard-00-00.gcsjylb.mongodb.net:27017,ac-z9ebeqz-shard-00-01.gcsjylb.mongodb.net:27017,ac-z9ebeqz-shard-00-02.gcsjylb.mongodb.net:27017/?ssl=true&replicaSet=atlas-12klt0-shard-0&authSource=admin&appName=Cluster0

## Local Development

If `MONGODB_URI` is not set, the app falls back to `LocalAuth` so you can still run it locally without changing the bot commands or routes.