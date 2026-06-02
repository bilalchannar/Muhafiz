const express = require("express");
const cors = require("cors");
require("dotenv").config();
const rateLimit = require("express-rate-limit");
const { Client, LocalAuth } = require("whatsapp-web.js");
const qrcode = require("qrcode-terminal");
const path = require("path");
const fs = require("fs");

const { connectDB, getDB } = require("./db");
const { validatePhone, validateMessage } = require("./utils/validation");
const authRoutes = require("./Routes/auth");

const app = express();
app.set("trust proxy", 1); // Trust proxy headers for accurate client IP rate limiting on Render
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const BOT_API_KEY = process.env.BOT_API_KEY || "muhafiz-bot-secret-key";
const WHATSAPP_BOT_URL = process.env.WHATSAPP_BOT_URL || `http://localhost:${PORT}`;

const WHATSAPP_CLIENT_ID = "muhafiz-whatsapp-bot";
const SESSION_PATH = path.resolve(
  process.env.SESSION_PATH || path.join(__dirname, "auth_session")
);

fs.mkdirSync(SESSION_PATH, { recursive: true });
console.log(`🗂️ WhatsApp session path: ${SESSION_PATH}`);
console.log(`🆔 WhatsApp client ID: ${WHATSAPP_CLIENT_ID}`);

// ── WhatsApp Client Setup ──────────────────────────────────────────────
let client;
let isClientReady = false;
let latestQrCode = null;

// Helper to delete corrupted or disconnected session files
function deleteSessionDir() {
  const sessionDir = path.join(SESSION_PATH, ".wwebjs_auth", `session-${WHATSAPP_CLIENT_ID}`);
  if (fs.existsSync(sessionDir)) {
    try {
      fs.rmSync(sessionDir, { recursive: true, force: true });
      console.log(`🗑️ Deleted session directory to reset authentication: ${sessionDir}`);
    } catch (err) {
      console.error(`❌ Failed to delete session directory:`, err);
    }
  }
}

function createWhatsAppClient() {
  const puppeteerOptions = {
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
      "--no-first-run",
      "--no-zygote",
      "--disable-extensions",
      "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      "--js-flags=--max-old-space-size=150",
      "--renderer-process-limit=1",
      "--disable-background-timer-throttling",
      "--disable-backgrounding-occluded-windows",
      "--disable-ipc-flooding-protection"
    ],
  };

  if (process.platform === "win32") {
    puppeteerOptions.executablePath = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
  } else if (process.env.PUPPETEER_EXECUTABLE_PATH) {
    puppeteerOptions.executablePath = process.env.PUPPETEER_EXECUTABLE_PATH;
  }

  client = new Client({
    authStrategy: new LocalAuth({
      clientId: WHATSAPP_CLIENT_ID,
      dataPath: SESSION_PATH,
    }),
    authTimeoutMs: 120000, // 2 minutes startup grace period
    qrTimeoutMs: 60000,    // 1 minute QR expiry period
    puppeteer: puppeteerOptions,
  });

  client.on("loading_screen", (percent, message) => {
    console.log(`⏳ WhatsApp Loading: ${percent}% - ${message}`);
  });

  client.on("qr", (qr) => {
    console.log("📲 WhatsApp QR code generated. Scan it with your phone.");
    qrcode.generate(qr, { small: true });
    latestQrCode = qr;
  });

  client.on("authenticated", () => {
    console.log("🔑 WhatsApp authenticated successfully");
  });

  client.on("auth_failure", async (msg) => {
    console.error("❌ WhatsApp Auth failure:", msg);
    isClientReady = false;
    latestQrCode = null;
    try {
      await client.destroy();
    } catch (_) {}
    deleteSessionDir(); // Clear corrupted session
    console.log("🔄 Reinitializing WhatsApp client...");
    createWhatsAppClient();
  });

  client.on("ready", () => {
    isClientReady = true;
    latestQrCode = null;
    console.log("✅ WhatsApp client is ready!");
  });

  client.on("disconnected", async (reason) => {
    isClientReady = false;
    latestQrCode = null;
    console.log("❌ WhatsApp client disconnected:", reason);
    try {
      await client.destroy();
    } catch (_) {}
    deleteSessionDir(); // Clear session to allow fresh login scan
    console.log("🔄 Reinitializing WhatsApp client...");
    createWhatsAppClient();
  });

  client.initialize();
}

/**
 * Normalise a phone number to the WhatsApp chat-id format.
 */
function formatPhone(phone) {
  let cleaned = String(phone).replace(/[\s\-\(\)]/g, "");
  if (cleaned.startsWith("+")) cleaned = cleaned.slice(1);
  if (cleaned.startsWith("00")) cleaned = cleaned.slice(2);
  return `${cleaned}@c.us`;
}

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
}

async function sendFallbackFCM(phone, message) {
  console.log(`[FCM FALLBACK] Sending Firebase Push Notification to account linked to ${phone}: "${message}"`);
}

// ── Routes ─────────────────────────────────────────────────────────────

// Mount Auth routes (with rate limiting)
app.use("/auth", authLimiter, authRoutes);

// Protected Message Send Route
app.post("/sendMessage", async (req, res) => {
  try {
    // Simple API Key validation for external systems, or authenticate via session
    const apiKey = req.headers["x-api-key"];
    if (apiKey !== BOT_API_KEY) {
      // If no API Key, require standard authMiddleware check
      // We will perform session auth check here if header exists
      const authHeader = req.headers.authorization;
      if (authHeader) {
        // Run auth inline
        const token = authHeader.startsWith("Bearer ") ? authHeader.split(" ")[1] : authHeader;
        const db = getDB();
        const session = db ? await db.collection("sessions").findOne({ sessionId: token }) : null;
        if (!session) {
          return res.status(401).json({ success: false, message: "Unauthorized: Invalid session" });
        }
      } else {
        return res.status(401).json({ success: false, message: "Unauthorized: Missing credentials" });
      }
    }

    const { phone, message } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ success: false, message: "phone and message are required" });
    }

    if (!validatePhone(phone) || !validateMessage(message)) {
      return res.status(400).json({ success: false, message: "Invalid phone number or message format" });
    }

    if (!isClientReady) {
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });
    }

    const chatId = formatPhone(phone);
    const isRegistered = await client.isRegisteredUser(chatId);
    if (!isRegistered) {
      return res.status(400).json({
        success: false,
        message: `Phone number ${phone} is not registered on WhatsApp.`,
      });
    }

    await client.sendMessage(chatId, message);
    console.log(`📨 Message sent to ${chatId}`);

    return res.status(200).json({ success: true, message: "Message sent successfully" });
  } catch (err) {
    console.error("Local /sendMessage failed:", err);
    return res.status(500).json({ success: false, message: err.message });
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

    if (!isClientReady) {
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });
    }

    const results = [];
    for (const p of phone) {
      if (!validatePhone(p)) {
        results.push({ phone: p, success: false, error: "Invalid phone format" });
        continue;
      }

      try {
        const chatId = formatPhone(p);
        const isRegistered = await client.isRegisteredUser(chatId);
        if (!isRegistered) {
          await triggerFallbackChannels(p, message);
          results.push({ phone: p, success: false, fallbackTriggered: true, error: "Not registered on WhatsApp" });
          continue;
        }

        await client.sendMessage(chatId, message);
        results.push({ phone: p, success: true });
      } catch (err) {
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

// View QR Code directly on the server
app.get("/qr", (req, res) => {
  if (isClientReady) {
    return res.send("<h1>✅ WhatsApp is already connected!</h1>");
  }

  if (!latestQrCode) {
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
        const qrText = ${JSON.stringify(latestQrCode)};
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
});

// Endpoint for internal API checks
app.get("/qr-code", (req, res) => {
  res.json({ qr: latestQrCode, ready: isClientReady });
});

// Proxy route for botInfo
app.get("/botInfo", authMiddleware, (req, res) => {
  if (!isClientReady || !client || !client.info) {
    return res.json({ ready: false, hasClient: !!client, hasInfo: !!(client && client.info) });
  }
  res.json({
    ready: true,
    wid: client.info.wid,
    pushname: client.info.pushname,
    platform: client.info.platform,
  });
});

// Proxy route for checkMessages
app.get("/checkMessages", authMiddleware, async (req, res) => {
  try {
    const { phone } = req.query;
    if (!phone) {
      return res.status(400).json({ success: false, message: "phone query param is required" });
    }
    if (!isClientReady) {
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });
    }
    const chatId = formatPhone(phone);
    const chat = await client.getChatById(chatId);
    if (!chat) {
      return res.json({ success: false, message: `No chat found for ${chatId}` });
    }
    const messages = await chat.fetchMessages({ limit: 5 });
    const formatted = messages.map(m => ({
      fromMe: m.fromMe,
      body: m.body,
      timestamp: m.timestamp,
      ack: m.ack,
    }));
    return res.json({ success: true, chatId, formatted });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// Health check
app.get("/health", (req, res) => {
  return res.json({ status: "ok", dbConnected: !!getDB(), whatsappBot: { status: isClientReady ? "online" : "offline" } });
});

// Connect to Database, start WhatsApp client, and boot Server
async function bootstrap() {
  try {
    await connectDB();
    createWhatsAppClient(); // Initializing WhatsApp Bot inside the same server process!
    app.listen(PORT, () => {
      console.log(`🚀 App API Server running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error("❌ Startup aborted due to database connection error.");
    process.exit(1);
  }
}

bootstrap();
