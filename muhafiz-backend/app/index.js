const express = require("express");
const cors = require("cors");
require("dotenv").config();
const rateLimit = require("express-rate-limit");

const { connectDB, getDB } = require("./db");
const { validatePhone, validateMessage } = require("./utils/validation");
const authRoutes = require("./Routes/auth");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const WHATSAPP_BOT_URL = process.env.WHATSAPP_BOT_URL || "http://localhost:3001";
const BOT_API_KEY = process.env.BOT_API_KEY || "muhafiz-bot-secret-key";

// ── IP-Based Rate Limiting ─────────────────────────────────────────────
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 requests per window
  message: {
    success: false,
    message: "Too many authentication requests from this IP. Please try again after 15 minutes."
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// ── Authentication Middleware ──────────────────────────────────────────
async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ success: false, message: "Unauthorized: Missing token" });
    }
    const token = authHeader.split(" ")[1];

    const db = getDB();
    if (!db) {
      return res.status(503).json({ success: false, message: "Database not initialized" });
    }

    const session = await db.collection("sessions").findOne({ sessionId: token });
    if (!session) {
      return res.status(401).json({ success: false, message: "Unauthorized: Invalid session" });
    }

    if (session.expiresAt && new Date() > new Date(session.expiresAt)) {
      await db.collection("sessions").deleteOne({ sessionId: token });
      return res.status(401).json({ success: false, message: "Unauthorized: Session expired" });
    }

    req.user = { phone: session.phone };
    next();
  } catch (err) {
    console.error("Auth middleware error:", err);
    return res.status(500).json({ success: false, message: "Authentication internal error" });
  }
}

// ── Fallback Delivery Channels ────────────────────────────────────────
async function triggerFallbackChannels(phone, message) {
  console.log(`⚠️ WhatsApp delivery failed for ${phone}. Activating fallback channels...`);
  await sendFallbackSMS(phone, message);
  await sendFallbackFCM(phone, message);
}

async function sendFallbackSMS(phone, message) {
  console.log(`[SMS FALLBACK] Sending SMS alert to ${phone}: "${message}"`);
  // Developers can easily plug in Twilio or another SMS gateway here:
  // const client = require('twilio')(accountSid, authToken);
  // await client.messages.create({ body: message, to: phone, from: twilioNumber });
}

async function sendFallbackFCM(phone, message) {
  console.log(`[FCM FALLBACK] Sending Firebase Push Notification to account linked to ${phone}: "${message}"`);
  // Developers can plug in Firebase Admin SDK here to send push alerts:
  // await admin.messaging().send({ token: userFcmToken, notification: { title: "SOS Emergency", body: message } });
}

// ── Routes ─────────────────────────────────────────────────────────────

// Mount Auth routes (with rate limiting)
app.use("/auth", authLimiter, authRoutes);

// Protected Message Send Route
app.post("/sendMessage", authMiddleware, async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ success: false, message: "phone and message are required" });
    }

    if (!validatePhone(phone) || !validateMessage(message)) {
      return res.status(400).json({ success: false, message: "Invalid phone number or message format" });
    }

    // Relay to the single WhatsApp bot service
    const response = await fetch(`${WHATSAPP_BOT_URL}/sendMessage`, {
      method: "POST",
      headers: { 
        "Content-Type": "application/json",
        "x-api-key": BOT_API_KEY
      },
      body: JSON.stringify({ phone, message }),
    });

    const result = await response.json();
    return res.status(response.status).json(result);
  } catch (err) {
    console.error("Relay /sendMessage failed:", err);
    return res.status(500).json({ success: false, message: "Failed to relay message to WhatsApp bot" });
  }
});

// Protected Mass Message Send Route with SMS/FCM Fallback
app.post("/sendMassMsg", authMiddleware, async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ success: false, message: "phone (array) and message are required" });
    }

    if (!Array.isArray(phone) || phone.length === 0) {
      return res.status(400).json({ success: false, message: "phone must be a non-empty array of strings" });
    }

    if (!validateMessage(message)) {
      return res.status(400).json({ success: false, message: "Invalid message format" });
    }

    const results = [];
    for (const p of phone) {
      if (!validatePhone(p)) {
        results.push({ phone: p, success: false, error: "Invalid phone format" });
        continue;
      }

      try {
        const response = await fetch(`${WHATSAPP_BOT_URL}/sendMessage`, {
          method: "POST",
          headers: { 
            "Content-Type": "application/json",
            "x-api-key": BOT_API_KEY
          },
          body: JSON.stringify({ phone: p, message }),
        });

        const result = await response.json();
        
        if (result.success) {
          results.push({ phone: p, success: true });
        } else {
          // If WhatsApp fails, trigger the fallback channels
          await triggerFallbackChannels(p, message);
          results.push({ phone: p, success: false, fallbackTriggered: true, error: result.message });
        }
      } catch (err) {
        // Network error or bot offline
        await triggerFallbackChannels(p, message);
        results.push({ phone: p, success: false, fallbackTriggered: true, error: err.message });
      }
    }

    return res.status(200).json({ success: true, results });
  } catch (err) {
    console.error("Error in /sendMassMsg:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// View QR Code proxy from WhatsApp Bot service
app.get("/qr", async (req, res) => {
  try {
    const response = await fetch(`${WHATSAPP_BOT_URL}/qr-code`);
    const status = await response.json();

    if (status.ready) {
      return res.send("<h1>✅ WhatsApp is already connected!</h1>");
    }

    if (!status.qr) {
      return res.send("<h1>⏳ QR Code not generated yet. Please wait or reload...</h1><meta http-equiv='refresh' content='5'>");
    }

    const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Scan WhatsApp QR Code</title>
      <script src="https://cdn.jsdelivr.net/npm/qrcode@1.4.4/build/qrcode.min.js"></script>
      <meta http-equiv="refresh" content="15">
      <style>
        body {
          font-family: sans-serif;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          background-color: #f0f2f5;
        }
        .container {
          background: white;
          padding: 30px;
          border-radius: 10px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
          text-align: center;
        }
        canvas {
          margin: 20px 0;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h2>Scan this QR Code</h2>
        <p>This page automatically refreshes every 15 seconds to keep the code fresh.</p>
        <canvas id="canvas"></canvas>
        <script>
          const qrText = ${JSON.stringify(status.qr)};
          if (qrText) {
            QRCode.toCanvas(document.getElementById('canvas'), qrText, { width: 300 }, function (error) {
              if (error) console.error(error);
            });
          }
        </script>
      </div>
    </body>
    </html>
    `;
    return res.send(html);
  } catch (err) {
    return res.status(500).send(`<h1>❌ Error connecting to WhatsApp bot microservice</h1><p>${err.message}</p>`);
  }
});

// Proxy route for botInfo
app.get("/botInfo", authMiddleware, async (req, res) => {
  try {
    const response = await fetch(`${WHATSAPP_BOT_URL}/botInfo`, {
      headers: { "x-api-key": BOT_API_KEY }
    });
    const result = await response.json();
    return res.status(response.status).json(result);
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// Proxy route for checkMessages
app.get("/checkMessages", authMiddleware, async (req, res) => {
  try {
    const { phone } = req.query;
    const response = await fetch(`${WHATSAPP_BOT_URL}/checkMessages?phone=${phone}`, {
      headers: { "x-api-key": BOT_API_KEY }
    });
    const result = await response.json();
    return res.status(response.status).json(result);
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// Health check
app.get("/health", async (_req, res) => {
  try {
    const response = await fetch(`${WHATSAPP_BOT_URL}/health`);
    const result = await response.json();
    return res.json({ status: "ok", dbConnected: !!getDB(), whatsappBot: result });
  } catch (err) {
    return res.json({ status: "ok", dbConnected: !!getDB(), whatsappBot: { status: "offline", error: err.message } });
  }
});

// Connect to MongoDB and start the Express server
async function bootstrap() {
  try {
    await connectDB();
    app.listen(PORT, () => {
      console.log(`🚀 App API Server running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error("❌ Startup aborted due to database connection error.");
    process.exit(1);
  }
}

bootstrap();
