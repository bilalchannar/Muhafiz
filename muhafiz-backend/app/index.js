const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
require("dotenv").config();
const { MongoClient } = require("mongodb");
const { Client, LocalAuth, RemoteAuth } = require("whatsapp-web.js");
const qrcode = require("qrcode-terminal");

const authRoutes = require("./Routes/auth");

const app = express();
app.use(cors());
app.use(express.json());

const SESSION_ID = process.env.SESSION_ID || "main-whatsapp-session";
const SESSION_PATH = path.resolve(
  process.env.SESSION_PATH || path.join(__dirname, "auth_session")
);
const MONGODB_URI = process.env.MONGODB_URI;
const MONGODB_DB_NAME = process.env.MONGODB_DB_NAME || "muhafiz";
const MONGODB_COLLECTION = process.env.MONGODB_COLLECTION || "whatsapp_sessions";

fs.mkdirSync(SESSION_PATH, { recursive: true });
console.log(`🗂️ WhatsApp temporary auth path: ${SESSION_PATH}`);
console.log(`🆔 WhatsApp session ID: ${SESSION_ID}`);

class MongoRemoteAuthStore {
  constructor({ mongoClient, dbName, collectionName, dataPath }) {
    this.mongoClient = mongoClient;
    this.dbName = dbName;
    this.collectionName = collectionName;
    this.dataPath = dataPath;
  }

  get collection() {
    return this.mongoClient.db(this.dbName).collection(this.collectionName);
  }

  async sessionExists({ session }) {
    const existing = await this.collection.findOne(
      { session },
      { projection: { _id: 1 } }
    );
    return !!existing;
  }

  async save({ session }) {
    const sessionZipPath = path.join(this.dataPath, `${session}.zip`);
    const sessionZip = await fs.promises.readFile(sessionZipPath);

    await this.collection.updateOne(
      { session },
      {
        $set: {
          session,
          data: sessionZip.toString("base64"),
          updatedAt: new Date(),
        },
      },
      { upsert: true }
    );

    console.log(`💾 Session saved to MongoDB: ${session}`);
  }

  async extract({ session, path: zipPath }) {
    const document = await this.collection.findOne({ session });

    if (!document) {
      return;
    }

    await fs.promises.mkdir(path.dirname(zipPath), { recursive: true });
    await fs.promises.writeFile(zipPath, Buffer.from(document.data, "base64"));
    console.log(`📦 Session loaded from MongoDB: ${session}`);
  }

  async delete({ session }) {
    await this.collection.deleteOne({ session });
  }
}

// ── WhatsApp Client Setup ──────────────────────────────────────────────
let whatsappClient;
let isWhatsAppReady = false;
let latestQrCode = null;
let mongoStore = null;

async function connectMongoIfConfigured() {
  if (!MONGODB_URI) {
    console.log("ℹ️ MONGODB_URI is not set. Using LocalAuth for local development.");
    return null;
  }

  const mongoClient = new MongoClient(MONGODB_URI, {
    serverSelectionTimeoutMS: 10000,
  });

  await mongoClient.connect();
  console.log("✅ MongoDB connected");

  return new MongoRemoteAuthStore({
    mongoClient,
    dbName: MONGODB_DB_NAME,
    collectionName: MONGODB_COLLECTION,
    dataPath: SESSION_PATH,
  });
}

function createWhatsAppClient() {
  const puppeteerOptions = {
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu"
    ],
  };

  if (process.platform === "win32") {
    puppeteerOptions.executablePath = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
  } else if (process.env.PUPPETEER_EXECUTABLE_PATH) {
    puppeteerOptions.executablePath = process.env.PUPPETEER_EXECUTABLE_PATH;
  }

  const authStrategy = mongoStore
    ? new RemoteAuth({
        clientId: SESSION_ID,
        store: mongoStore,
        dataPath: SESSION_PATH,
        backupSyncIntervalMs: 60000,
        rmMaxRetries: 3,
      })
    : new LocalAuth({
        clientId: SESSION_ID,
        dataPath: SESSION_PATH,
      });

  whatsappClient = new Client({
    authStrategy,
    puppeteer: puppeteerOptions,
  });

  whatsappClient.on("loading_screen", (percent, message) => {
    console.log(`⏳ WhatsApp Loading: ${percent}% - ${message}`);
  });

  whatsappClient.on("qr", (qr) => {
    console.log("📲 WhatsApp QR code generated. Scan it with your phone.");
    qrcode.generate(qr, { small: true });
    console.log("RAW_QR_DATA:" + qr);
    latestQrCode = qr;
    console.log(`💾 QR code generated for session ${SESSION_ID}`);
  });

  whatsappClient.on("authenticated", () => {
    console.log("🔑 WhatsApp authenticated successfully");
  });

  whatsappClient.on("auth_failure", async (msg) => {
    console.error("❌ WhatsApp auth failure:", msg);
    isWhatsAppReady = false;
    try {
      await whatsappClient.destroy();
    } catch (_) {}
    console.log("🔄 Reinitializing WhatsApp client...");
    createWhatsAppClient();
  });

  whatsappClient.on("ready", () => {
    isWhatsAppReady = true;
    latestQrCode = null;
    console.log("✅ WhatsApp client is ready!");
  });

  whatsappClient.on("disconnected", async (reason) => {
    isWhatsAppReady = false;
    console.log("❌ WhatsApp client disconnected:", reason);
    try {
      await whatsappClient.destroy();
    } catch (_) {}
    console.log("🔄 Reinitializing WhatsApp client...");
    createWhatsAppClient();
  });

  whatsappClient.initialize();
}

async function bootstrap() {
  try {
    mongoStore = await connectMongoIfConfigured();
    createWhatsAppClient();
  } catch (err) {
    console.error("❌ Failed to start WhatsApp bot:", err);
    process.exit(1);
  }
}

bootstrap();

/**
 * Normalise a phone number to the WhatsApp chat-id format.
 */
function formatPhone(phone) {
  let cleaned = String(phone).replace(/[\s\-\(\)]/g, "");
  if (cleaned.startsWith("+")) cleaned = cleaned.slice(1);
  if (cleaned.startsWith("00")) cleaned = cleaned.slice(2);
  return `${cleaned}@c.us`;
}

// ── Routes ─────────────────────────────────────────────────────────────
app.use("/auth", authRoutes);

app.get("/qr", (req, res) => {
  if (isWhatsAppReady) {
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
  res.send(html);
});

app.post("/sendMessage", async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res
        .status(400)
        .json({ success: false, message: "phone and message are required" });
    }

    if (!isWhatsAppReady) {
      return res
        .status(503)
        .json({ success: false, message: "WhatsApp client is not ready yet" });
    }

    const chatId = formatPhone(phone);

    const isRegistered = await whatsappClient.isRegisteredUser(chatId);
    if (!isRegistered) {
      console.warn(`⚠️ Warning: Phone number ${chatId} is NOT registered on WhatsApp.`);
      return res.status(400).json({
        success: false,
        message: `Phone number ${phone} is not registered on WhatsApp. Please check the number.`,
      });
    }

    await whatsappClient.sendMessage(chatId, message);
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

app.get("/botInfo", (req, res) => {
  if (!isWhatsAppReady || !whatsappClient || !whatsappClient.info) {
    return res.json({ ready: false, hasClient: !!whatsappClient, hasInfo: !!(whatsappClient && whatsappClient.info) });
  }
  res.json({
    ready: true,
    wid: whatsappClient.info.wid,
    pushname: whatsappClient.info.pushname,
    platform: whatsappClient.info.platform,
  });
});

app.get("/checkMessages", async (req, res) => {
  try {
    const { phone } = req.query;
    if (!phone) {
      return res.status(400).json({ success: false, message: "phone query param is required" });
    }
    if (!isWhatsAppReady) {
      return res.status(503).json({ success: false, message: "WhatsApp client is not ready yet" });
    }
    const chatId = formatPhone(phone);
    const chat = await whatsappClient.getChatById(chatId);
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

// ── Mass Message ───────────────────────────────────────────────────────
app.post("/sendMassMsg", async (req, res) => {
  try {
    const { phone, message } = req.body;

    if (!phone || !message) {
      return res.status(400).json({ success: false, message: "phone and message are required" });
    }

    if (!Array.isArray(phone) || phone.length === 0) {
      return res.status(400).json({ success: false, message: "phone must be a non-empty array of strings" });
    }

    const results = [];
    for (const p of phone) {
      try {
        const response = await fetch(`http://localhost:${PORT}/sendMessage`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ phone: p, message }),
        });
        const result = await response.json();
        results.push({ phone: p, success: result.success, response: result });
      } catch (err) {
        results.push({ phone: p, success: false, error: err.message });
      }
    }

    return res.status(200).json({ success: true, results });
  } catch (err) {
    console.error("Error in /sendMassMsg:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ── Health check ───────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok", whatsappReady: isWhatsAppReady });
});

// ── Start server ───────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 App server running on http://localhost:${PORT}`);
});

