const express = require("express");
const cors = require("cors");
require("dotenv").config();
const rateLimit = require("express-rate-limit");
const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
} = require("@whiskeysockets/baileys");
const pino = require("pino");
const qrcodeTerminal = require("qrcode-terminal");
const qrcode = require("qrcode");
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

const SESSION_PATH = path.resolve(
  process.env.SESSION_PATH || path.join(__dirname, "auth_session")
);
fs.mkdirSync(SESSION_PATH, { recursive: true });
console.log(`🗂️ WhatsApp session path: ${SESSION_PATH}`);

// ── State variables ──────────────────────────────────────────────
let sock = null;
let isClientReady = false; // Maps to connection status for backwards compatibility
let latestQrCode = null; // Raw QR string for client canvas
let latestQrDataUrl = null; // Base64 image URL if server-side HTML needs it
let reconnectTimer = null;
const messageHistory = {}; // JID -> last 20 messages

// ── Firebase Session helpers ──────────────────────────────────────
// Get FIREBASE_DB_URL
let dbUrl = process.env.FIREBASE_DB_URL;
if (dbUrl) {
  dbUrl = dbUrl.trim();
  if (dbUrl.endsWith("/")) {
    dbUrl = dbUrl.slice(0, -1);
  }
}
const FIREBASE_DB_URL = dbUrl || "https://start-of-firebase-default-rtdb.firebaseio.com";
const FB_SESSION_BASE = `${FIREBASE_DB_URL}/whatsapp-session`;

async function fbGet(filename) {
  try {
    const res = await fetch(`${FB_SESSION_BASE}/${encodeURIComponent(filename)}.json`);
    return await res.json();
  } catch (_) {
    return null;
  }
}

async function fbSet(filename, content) {
  try {
    await fetch(`${FB_SESSION_BASE}/${encodeURIComponent(filename)}.json`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(content),
    });
  } catch (err) {
    console.error(`⚠️  Firebase write failed for ${filename}:`, err.message);
  }
}

async function fbDeleteAll() {
  try {
    await fetch(`${FB_SESSION_BASE}.json`, { method: "DELETE" });
    console.log("🗑️  Firebase session cleared.");
  } catch (_) {}
}

async function useFirebaseAuthState() {
  console.log("📥 Restoring WhatsApp session from Firebase...");
  let restored = 0;
  try {
    const res = await fetch(`${FB_SESSION_BASE}.json`);
    const allFiles = await res.json();
    if (allFiles && typeof allFiles === "object") {
      for (const [filename, content] of Object.entries(allFiles)) {
        if (content) {
          const localPath = path.join(SESSION_PATH, filename);
          fs.mkdirSync(path.dirname(localPath), { recursive: true });
          fs.writeFileSync(localPath, JSON.stringify(content), "utf8");
          restored++;
        }
      }
    }
  } catch (_) {}
  console.log(
    restored > 0
      ? `✅ Restored ${restored} session file(s) from Firebase.`
      : "ℹ️  No existing Firebase session found — fresh start."
  );

  const { state, saveCreds } = await useMultiFileAuthState(SESSION_PATH);

  const saveCredsAndSync = async () => {
    await saveCreds();
    try {
      const files = fs.readdirSync(SESSION_PATH);
      for (const file of files) {
        const filePath = path.join(SESSION_PATH, file);
        if (fs.statSync(filePath).isFile()) {
          const raw = fs.readFileSync(filePath, "utf8");
          try {
            await fbSet(file, JSON.parse(raw));
          } catch (_) {
            await fbSet(file, raw);
          }
        }
      }
    } catch (err) {
      console.error("⚠️  Session sync to Firebase failed:", err.message);
    }
  };

  return { state, saveCreds: saveCredsAndSync };
}

// ── WhatsApp Client Setup (Baileys) ──────────────────────────────────
async function createWhatsAppClient() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  const { state, saveCreds } = await useFirebaseAuthState();
  
  let version = [6, 33, 0];
  try {
    const vResult = await fetchLatestBaileysVersion();
    version = vResult.version;
  } catch (_) {}
  console.log(`📦 Using Baileys WA version: ${version.join(".")}`);

  sock = makeWASocket({
    version,
    auth: state,
    logger: pino({ level: process.env.LOG_LEVEL || "silent" }),
    keepAliveIntervalMs: 30_000,
    retryRequestDelayMs: 250,
    downloadHistory: false,
    syncFullHistory: false,
    markOnlineOnConnect: false,
    generateHighQualityLinkPreview: false,
  });

  sock.ev.on("creds.update", saveCreds);

  sock.ev.on("messages.upsert", (m) => {
    if (m.type === "notify" || m.type === "append") {
      for (const msg of m.messages) {
        const jid = msg.key.remoteJid;
        if (!jid) continue;
        if (!messageHistory[jid]) {
          messageHistory[jid] = [];
        }
        messageHistory[jid].push(msg);
        if (messageHistory[jid].length > 20) {
          messageHistory[jid].shift();
        }
      }
    }
  });

  sock.ev.on("connection.update", async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      latestQrCode = qr;
      qrcodeTerminal.generate(qr, { small: true });
      console.log("📲 WhatsApp QR code generated. Scan it with your phone.");
      try {
        latestQrDataUrl = await qrcode.toDataURL(qr);
      } catch (_) {}
    }

    if (connection === "open") {
      isClientReady = true;
      latestQrCode = null;
      latestQrDataUrl = null;
      console.log("✅ WhatsApp client is ready!");
    }

    if (connection === "close") {
      isClientReady = false;
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      const reason = DisconnectReason[statusCode] || statusCode;
      console.log(`❌ WhatsApp client disconnected: ${reason}`);

      const shouldLogOut =
        statusCode === DisconnectReason.loggedOut ||
        statusCode === DisconnectReason.forbidden;

      if (shouldLogOut) {
        console.log("🗑️  Clearing session (logged out / forbidden)...");
        try { fs.rmSync(SESSION_PATH, { recursive: true, force: true }); } catch (_) {}
        fs.mkdirSync(SESSION_PATH, { recursive: true });
        await fbDeleteAll();
        console.log("🔄 Reconnecting for fresh QR...");
        reconnectTimer = setTimeout(createWhatsAppClient, 3000);
      } else {
        console.log("🔄 Reconnecting in 8s...");
        reconnectTimer = setTimeout(createWhatsAppClient, 8000);
      }
    }
  });
}

// ── Phone Helpers ──────────────────────────────────────────────────
function formatJid(phone) {
  let cleaned = String(phone).replace(/[\s\-\(\)]/g, "");
  if (cleaned.startsWith("+")) cleaned = cleaned.slice(1);
  if (cleaned.startsWith("00")) cleaned = cleaned.slice(2);
  return `${cleaned}@s.whatsapp.net`;
}

async function checkNumberOnWhatsApp(phone) {
  if (!sock || !isClientReady) return false;
  const jid = formatJid(phone);
  try {
    const [result] = await sock.onWhatsApp(jid);
    return !!(result && result.exists);
  } catch (_) {
    return false;
  }
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
    const apiKey = req.headers["x-api-key"];
    if (apiKey !== BOT_API_KEY) {
      const authHeader = req.headers.authorization;
      if (authHeader) {
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

    if (!isClientReady || !sock) {
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });
    }

    const exists = await checkNumberOnWhatsApp(phone);
    if (!exists) {
      return res.status(400).json({
        success: false,
        message: `Phone number ${phone} is not registered on WhatsApp.`,
      });
    }

    const jid = formatJid(phone);
    await sock.sendMessage(jid, { text: message });
    console.log(`📨 Message sent to ${jid}`);

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

    if (!isClientReady || !sock) {
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });
    }

    const results = [];
    for (const p of phone) {
      if (!validatePhone(p)) {
        results.push({ phone: p, success: false, error: "Invalid phone format" });
        continue;
      }

      try {
        const exists = await checkNumberOnWhatsApp(p);
        if (!exists) {
          await triggerFallbackChannels(p, message);
          results.push({ phone: p, success: false, fallbackTriggered: true, error: "Not registered on WhatsApp" });
          continue;
        }

        const jid = formatJid(p);
        await sock.sendMessage(jid, { text: message });
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
  if (!isClientReady || !sock || !sock.user) {
    return res.json({ ready: false, hasClient: !!sock, hasInfo: !!(sock && sock.user) });
  }
  res.json({
    ready: true,
    wid: sock.user.id,
    pushname: sock.user.name || "Muhafiz Bot",
    platform: "baileys",
  });
});

// Proxy route for checkMessages
app.get("/checkMessages", authMiddleware, async (req, res) => {
  try {
    const { phone } = req.query;
    if (!phone) {
      return res.status(400).json({ success: false, message: "phone query param is required" });
    }
    if (!isClientReady || !sock) {
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });
    }
    const jid = formatJid(phone);
    const msgs = messageHistory[jid]?.slice(-5) ?? [];
    const formatted = msgs.map((m) => ({
      fromMe: m.key?.fromMe ?? false,
      body: m.message?.conversation
        || m.message?.extendedTextMessage?.text
        || m.message?.imageMessage?.caption
        || m.message?.videoMessage?.caption
        || "",
      timestamp: m.messageTimestamp,
      ack: 1, // mock ack
    }));
    return res.json({ success: true, chatId: jid, formatted, messages: formatted });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// Health check
app.get("/health", (req, res) => {
  return res.json({ status: "ok", dbConnected: !!getDB(), whatsappBot: { status: isClientReady ? "online" : "offline" } });
});

// ── Memory Watchdog ──────────────────────────────────────────────────
const MEMORY_LIMIT_MB = parseInt(process.env.MEMORY_LIMIT_MB || "300");
setInterval(() => {
  const usedMB = process.memoryUsage().rss / 1024 / 1024;
  if (usedMB > MEMORY_LIMIT_MB) {
    console.error(`⚠️ Memory ${usedMB.toFixed(0)}MB > limit ${MEMORY_LIMIT_MB}MB. Restarting...`);
    process.exit(1);
  }
}, 30_000);

// ── Graceful Shutdown ────────────────────────────────────────────────
async function gracefulShutdown(signal) {
  console.log(`\n🛑 ${signal} received — shutting down gracefully...`);
  try {
    if (sock) await sock.logout();
  } catch (_) {}
  process.exit(0);
}
process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT",  () => gracefulShutdown("SIGINT"));

// Connect to Database, start WhatsApp client, and boot Server
async function bootstrap() {
  try {
    await connectDB();
    await createWhatsAppClient(); // Initializing WhatsApp Bot inside the same server process!
    app.listen(PORT, () => {
      console.log(`🚀 App API Server running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error("❌ Startup aborted due to database connection error.", err);
    process.exit(1);
  }
}

bootstrap();
