const fs = require("fs");
const path = require("path");
const { Client, LocalAuth } = require("whatsapp-web.js");
const qrcode = require("qrcode-terminal");
const express = require("express");
require("dotenv").config();
const app = express();
app.use(express.json());

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

function createClient() {
  const puppeteerOptions = {
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
      "--no-first-run",
      "--no-zygote",
      "--single-process", // Essential to conserve memory on Render Free Tier
      "--disable-extensions"
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
    webVersionCache: {
      type: "remote",
      remotePath: "https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html",
    },
    puppeteer: puppeteerOptions,
  });

  client.on("loading_screen", (percent, message) => {
    console.log(`⏳ Loading: ${percent}% - ${message}`);
  });

  client.on("qr", (qr) => {
    console.log("📲 WhatsApp QR code generated. Scan it with your phone.");
    qrcode.generate(qr, { small: true });
    latestQrCode = qr;
    console.log(`💾 QR code stored for the /qr page at ${SESSION_PATH}`);
  });

  client.on("authenticated", () => {
    console.log("🔑 WhatsApp authenticated successfully");
    console.log(`💾 WhatsApp credentials/session saved in ${SESSION_PATH}`);
  });

  client.on("auth_failure", async (msg) => {
    console.error("❌ Auth failure:", msg);
    isClientReady = false;
    latestQrCode = null;
    try {
      await client.destroy();
    } catch (_) {}
    deleteSessionDir(); // Clear corrupted session
    console.log("🔄 Reinitializing client...");
    createClient();
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
    console.log("🔄 Reinitializing client...");
    createClient();
  });

  client.initialize();
}

createClient();

/**
 * Normalise a phone number to the WhatsApp chat-id format.
 * Strips leading "+", "00", spaces, dashes, etc.
 * Result: "<countryCode><number>@c.us"
 */
function formatPhone(phone) {
  let cleaned = String(phone).replace(/[\s\-\(\)]/g, "");
  if (cleaned.startsWith("+")) cleaned = cleaned.slice(1);
  if (cleaned.startsWith("00")) cleaned = cleaned.slice(2);
  return `${cleaned}@c.us`;
}

// ── Routes ─────────────────────────────────────────────────────────────

const BOT_API_KEY = process.env.BOT_API_KEY || "muhafiz-bot-secret-key";

// Simple API Key middleware
app.use((req, res, next) => {
  // Allow health and QR endpoints without API key so devs/admins can check status and scan QR code in browser
  if (
    req.path === "/health" ||
    req.path === "/qr" ||
    req.path === "/qr-code"
  ) {
    return next();
  }
  const apiKey = req.headers["x-api-key"];
  if (!apiKey || apiKey !== BOT_API_KEY) {
    return res.status(401).json({ success: false, message: "Unauthorized: Invalid API Key" });
  }
  next();
});

// JSON endpoint for QR code
app.get("/qr-code", (req, res) => {
  res.json({ qr: latestQrCode, ready: isClientReady });
});

// HTML page for scanning QR code directly on the bot service
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
      <h2>Scan this QR Code (WhatsApp Bot)</h2>
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
  res.send(html);
});

/**
 * POST /sendMessage
 * Body: { "phone": "923001234567", "message": "Hello!" }
 *
 * Generic message relay — your main backend calls this
 * whenever it needs to send any WhatsApp message (OTP, alert, etc.).
 */
app.post("/sendMessage", async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res
        .status(400)
        .json({ success: false, message: "phone and message are required" });
    }

    if (!isClientReady) {
      return res
        .status(503)
        .json({ success: false, message: "WhatsApp client is not ready yet" });
    }

    const chatId = formatPhone(phone);

    // Check if the user is registered on WhatsApp
    const isRegistered = await client.isRegisteredUser(chatId);
    if (!isRegistered) {
      console.warn(`⚠️ Warning: Phone number ${chatId} is NOT registered on WhatsApp.`);
      return res.status(400).json({
        success: false,
        message: `Phone number ${phone} is not registered on WhatsApp. Please check the number.`,
      });
    }

    await client.sendMessage(chatId, message);

    console.log(`📨 Message sent to ${chatId}`);

    return res.status(200).json({
      success: true,
      message: "Message sent successfully",
    });
  } catch (err) {
    console.error("Error in /sendMessage:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ── Health check ───────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok", whatsappReady: isClientReady });
});

app.get("/botInfo", (req, res) => {
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

app.get("/checkMessages", async (req, res) => {
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
      ack: m.ack, // 0 = ACK_ERROR, 1 = ACK_PENDING, 2 = ACK_SERVER, 3 = ACK_DEVICE, 4 = ACK_READ
    }));
    return res.json({ success: true, chatId, formatted });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

const PORT = process.env.PORT;
app.listen(PORT, () => {
  console.log(`🚀 WhatsApp Bot server running on http://localhost:${PORT}`);
});
