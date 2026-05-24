const { Client, LocalAuth } = require("whatsapp-web.js");
const qrcode = require("qrcode-terminal");
const express = require("express");
require("dotenv").config();
const app = express();
app.use(express.json());


// ── WhatsApp Client Setup ──────────────────────────────────────────────
let client;
let isClientReady = false;

function createClient() {
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

  client = new Client({
    authStrategy: new LocalAuth(),
    puppeteer: puppeteerOptions,
  });

  client.on("loading_screen", (percent, message) => {
    console.log(`⏳ Loading: ${percent}% - ${message}`);
  });

  client.on("qr", (qr) => {
    console.log("Scan this QR code with your WhatsApp:");
    qrcode.generate(qr, { small: true });
  });

  client.on("authenticated", () => {
    console.log("🔑 Authenticated successfully");
  });

  client.on("auth_failure", async (msg) => {
    console.error("❌ Auth failure:", msg);
    isClientReady = false;
    // Destroy the old client and re-create so a fresh QR is shown
    try {
      await client.destroy();
    } catch (_) {}
    console.log("🔄 Reinitializing client...");
    createClient();
  });

  client.on("ready", () => {
    isClientReady = true;
    console.log("✅ WhatsApp client is ready!");
  });

  client.on("disconnected", async (reason) => {
    isClientReady = false;
    console.log("❌ WhatsApp client disconnected:", reason);
    // Auto-reconnect
    try {
      await client.destroy();
    } catch (_) {}
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
