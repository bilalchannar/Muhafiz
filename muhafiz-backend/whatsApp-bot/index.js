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

// ── Memory Watchdog ─────────────────────────────────────────────────────
// Render free tier has ~512MB RAM. If we exceed 420MB, restart the process
// so Render can recover instead of getting OOM-killed mid-session.
const MEMORY_LIMIT_MB = parseInt(process.env.MEMORY_LIMIT_MB || "420");
setInterval(() => {
  const usedMB = process.memoryUsage().rss / 1024 / 1024;
  if (usedMB > MEMORY_LIMIT_MB) {
    console.error(`⚠️ Memory usage ${usedMB.toFixed(0)}MB exceeds limit ${MEMORY_LIMIT_MB}MB. Restarting process...`);
    process.exit(1); // Render will auto-restart the service
  }
}, 30_000); // check every 30s

function createClient() {
  const puppeteerOptions = {
    headless: true,
    args: [
      // Security sandbox (required for Docker/Render)
      "--no-sandbox",
      "--disable-setuid-sandbox",

      // Memory & process reduction
      "--disable-dev-shm-usage",        // Use /tmp instead of /dev/shm (critical for Render)
      "--single-process",               // Run renderer in browser process (saves ~80MB)
      "--no-zygote",                    // No zygote process (saves memory)
      "--js-flags=--max-old-space-size=128", // Limit V8 heap to 128MB

      // Disable unnecessary features to save RAM
      "--disable-gpu",
      "--disable-software-rasterizer",
      "--disable-extensions",
      "--disable-default-apps",
      "--disable-sync",
      "--disable-translate",
      "--disable-background-networking",
      "--disable-client-side-phishing-detection",
      "--disable-hang-monitor",
      "--disable-popup-blocking",
      "--disable-prompt-on-repost",
      "--disable-renderer-backgrounding",
      "--disable-background-timer-throttling",
      "--disable-backgrounding-occluded-windows",
      "--disable-ipc-flooding-protection",
      "--metrics-recording-only",
      "--mute-audio",
      "--no-first-run",
      "--safebrowsing-disable-auto-update",

      // Reduce network overhead
      "--no-proxy-server",

      // Keep UA consistent
      "--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    ],
    // Block images, fonts, stylesheets — WhatsApp Web only needs JS/XHR
    // This significantly reduces CPU & memory during loading
    protocolTimeout: 120000,
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
    authTimeoutMs: 180000, // 3 minutes — Render is slow, give it more time
    qrTimeoutMs: 90000,    // 90s QR expiry
    // Cache the WhatsApp Web version locally so it doesn't re-download on every restart
    webVersionCache: {
      type: "local",
      path: path.join(SESSION_PATH, "wwebjs_cache"),
    },
    puppeteer: puppeteerOptions,
  });

  client.on("loading_screen", (percent, message) => {
    console.log(`⏳ WhatsApp Loading: ${percent}% - ${message}`);
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
    console.log("🔄 Reinitializing client in 5s...");
    setTimeout(createClient, 5000);
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
    // Only clear session for auth-related disconnects, not for network blips
    if (reason === "LOGOUT" || reason === "CONFLICT") {
      deleteSessionDir();
    }
    console.log("🔄 Reinitializing client in 10s...");
    setTimeout(createClient, 10000); // Wait 10s before reconnect to avoid hammering memory
  });

  client.initialize();
}

createClient();

// ── Graceful Shutdown ──────────────────────────────────────────────────
// Render sends SIGTERM before killing the container. Destroy Chromium cleanly
// so the session files are flushed and the next deploy starts clean.
async function gracefulShutdown(signal) {
  console.log(`\n🛑 Received ${signal}. Shutting down gracefully...`);
  try {
    if (client) await client.destroy();
  } catch (_) {}
  process.exit(0);
}
process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT",  () => gracefulShutdown("SIGINT"));



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
